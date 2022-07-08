#!/usr/bin/env bb

(require '[babashka.deps :as deps]
         '[babashka.fs :as fs]
         '[clojure.java.io :as io]
         '[clojure.string :as str]
         '[org.httpkit.server :as server])

(import '[java.net URLDecoder])

(deps/add-deps '{:deps {co.insilica/bb-srvc {:mvn/version "0.6.0"}}})

(require '[insilica.canonical-json :as json]
         '[srvc.bb :as sb]
         '[srvc.bb.json-schema :as bjs])

(def resource-path
  (-> *file*
      fs/real-path ; Resolve symlinks
      fs/parent
      (fs/path "resources")))

(defn resource-file [uri]
  {:status 200
   :body (->> uri
              URLDecoder/decode
              (fs/path resource-path)
              str
              io/file)})

(defn json-response [json]
  {:status 200
   :headers {"Content-Type" "application/json"}
   :body (json/write-str json)})

(defn submit-answers [{:keys [body]} {:keys [current-doc next-doc! writer]}]
  (doseq [answer (-> body io/reader json/read)]
    (let [{:keys [errors valid?]} (-> (assoc answer :hash "")
                                      json/write-str json/read-str
                                      bjs/validate)]
      (if valid?
        (sb/write-event writer answer)
        (throw (ex-info "Event failed validation"
                        {:errors errors :event answer})))))
  (reset! current-doc (next-doc!))
  (json-response {:success true}))

(defn handler [{:keys [config current-doc] :as opts}]
 (fn [{:keys [request-method uri] :as request}]
   (cond
     (= "/" uri)
     (resource-file "public/recogito.html")

     (= "/config" uri)
     (json-response config)

     (= "/current-doc" uri)
     (json-response @current-doc)

     (and (= :post request-method)
          (= "/submit-label-answers" uri))
     (submit-answers request opts)

     (str/starts-with? uri "/public/")
     (resource-file (subs uri 1))

     :else
     {:status 404 :body "Not Found"})))

(let [config-file (System/getenv "SR_CONFIG")
      in-file (System/getenv "SR_INPUT")
      out-file (System/getenv "SR_OUTPUT")
      config (sb/get-config config-file)]
  (with-open [writer (io/writer out-file)]
    (let [lines (-> in-file io/reader line-seq atom)
          next-doc! (fn []
                      (when-let [line (first @lines)]
                        (.write writer line)
                        (.write writer "\n")
                        (.flush writer)
                        (swap! lines rest)
                        (let [{:keys [type] :as event} (json/read-str line :key-fn keyword)]
                          (if (= "document" type)
                            event
                            (recur)))))
          current-doc (atom (next-doc!))
          server (server/run-server
                  (handler {:config config
                            :current-doc current-doc
                            :next-doc! next-doc!
                            :writer writer})
                  {:ip "127.0.0.1"
                   :legacy-return-value? false
                   :port (:port config 0)})]
      (println (str "Listening on http://127.0.0.1:" (server/server-port server)))
      (Thread/sleep Long/MAX_VALUE))))
