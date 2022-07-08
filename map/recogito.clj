#!/usr/bin/env bb

(require '[babashka.deps :as deps]
         '[babashka.fs :as fs]
         '[clojure.java.io :as io]
         '[clojure.string :as str]
         '[org.httpkit.server :as server])

(import '[java.net URLDecoder])

(deps/add-deps '{:deps {co.insilica/bb-srvc {:mvn/version "0.6.0"}}})

(require '[insilica.canonical-json :as json]
         '[srvc.bb :as sb])

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

(defn handler [current-doc]
 (fn [{:keys [uri]}]
   (cond
     (= "/" uri)
     (resource-file "public/recogito.html")

     (= "/current-doc" uri)
     {:status 200
      :headers {"Content-Type" "application/json"}
      :body (json/write-str @current-doc)}

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
                  (handler current-doc)
                  {:ip "127.0.0.1"
                   :legacy-return-value? false
                   :port (:port config 0)})]
      (println (str "Listening on http://127.0.0.1:" (server/server-port server)))
      (Thread/sleep Long/MAX_VALUE))))
