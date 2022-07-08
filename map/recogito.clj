#!/usr/bin/env bb

(require '[babashka.deps :as deps]
         '[babashka.fs :as fs]
         '[clojure.java.io :as io]
         '[clojure.string :as str]
         '[org.httpkit.server :as server])

(import '[java.net URLDecoder])

(deps/add-deps '{:deps {co.insilica/bb-srvc {:mvn/version "0.5.0"}}})

(require '[insilica.canonical-json :as json]
         '[srvc.bb :as sb])

(def config
  (-> (System/getenv "SR_CONFIG")
      slurp
      (json/read-str :key-fn keyword)))

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

(defn handler [{:keys [uri]}]
  (cond
    (= "/" uri)
    (resource-file "public/recogito.html")

    (str/starts-with? uri "/public/")
    (resource-file (subs uri 1))

    :else
    {:status 404 :body "Not Found"}))

(def server
  (server/run-server
   handler
   {:ip "127.0.0.1"
    :legacy-return-value? false
    :port (:port config 0)}))

(println (str "Listening on http://127.0.0.1:" (server/server-port server)))

(Thread/sleep (Long/MAX_VALUE))
