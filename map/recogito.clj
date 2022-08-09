#!/usr/bin/env bb

(require '[babashka.deps :as deps]
         '[babashka.fs :as fs]
         '[clojure.java.io :as io]
         '[clojure.string :as str]
         '[org.httpkit.server :as server])

(import '[java.net URLDecoder])

(deps/add-deps '{:deps {co.insilica/bb-srvc {:mvn/version "0.7.0"}}})

(require '[clojure.data.json :as json]
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

(defn submit-answers [{:keys [body]} {:keys [current-doc-events next-doc-events! writer]}]
  (doseq [event @current-doc-events]
    (sb/write-event writer event))
  (doseq [answer (-> body io/reader json/read)]
    (let [{:keys [errors valid?]} (-> (assoc answer :hash "")
                                      json/write-str json/read-str
                                      bjs/validate)
          {:valid? true}]
      (if valid?
        (sb/write-event writer answer)
        (throw (ex-info "Event failed validation"
                        {:errors errors :event answer})))))
  (reset! current-doc-events (next-doc-events!))
  (json-response {:success true}))

(defn handler [{:keys [config current-doc-events] :as opts}]
 (fn [{:keys [request-method uri] :as request}]
   (cond
     (= "/" uri)
     (resource-file "public/recogito.html")

     (= "/config" uri)
     (json-response config)

     (= "/current-doc-events" uri)
     (json-response @current-doc-events)

     (and (= :post request-method)
          (= "/submit-label-answers" uri))
     (submit-answers request opts)

     (str/starts-with? uri "/public/")
     (resource-file (subs uri 1))

     :else
     {:status 404 :body "Not Found"})))

(defn partition-by-doc [lines]
  (lazy-seq
   (when-let [line (first lines)]
     (let [event (json/read-str line :key-fn keyword)]
       (loop [acc (transient [event])
              [line & more :as lines] (next lines)]
         (let [{:keys [type] :as event} (some-> line (json/read-str :key-fn keyword))]
           (cond
             (nil? line) [(persistent! acc)]
             (= "document" type) (cons (persistent! acc)
                                       (partition-by-doc lines))
             :else (recur (conj! acc event) more))))))))

(defn write-leading-non-docs [writer by-doc]
  (if (= "document" (:type (ffirst by-doc)))
    by-doc
    (do
      (doseq [event (first by-doc)]
        (sb/write-event writer event))
      (rest by-doc))))

(defn socket [addr]
  (let [[host port] (str/split addr #"\:")]
    (java.net.Socket. host (parse-long port))))

(defn socket-lines [addr]
  (-> addr socket io/reader line-seq))

(let [config (sb/get-config)]
  (with-open [writer (sb/get-output-writer)]
    (let [by-doc (->> (sb/get-input-lines)
                      partition-by-doc
                      (write-leading-non-docs writer)
                      atom)
          next-doc-events! (fn []
                             (let [events (first @by-doc)]
                               (swap! by-doc rest)
                               events))
          current-doc-events (atom (next-doc-events!))
          server (server/run-server
                  (handler {:config config
                            :current-doc-events current-doc-events
                            :next-doc-events! next-doc-events!
                            :writer writer})
                  {:ip "127.0.0.1"
                   :legacy-return-value? false
                   :port (:port config 0)})
          port (server/server-port server)]
      (sb/write-event writer {:type "control"
                              :data {:http-port port
                                     :timestamp (quot (System/currentTimeMillis) 1000)}})
      (println (str "Listening on http://127.0.0.1:" port))
      (Thread/sleep Long/MAX_VALUE))))
