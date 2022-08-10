#!/usr/bin/env bb
(require '[babashka.deps :as deps])
(deps/add-deps '{:deps {co.insilica/bb-srvc {:mvn/version "0.4.0"}}})
(require '[srvc.bb :as sb])
(require '[babashka.curl :as curl])
(require '[cheshire.core :as json])

(defn main [args]
  (let [[url] args
        docs (-> (curl/get url)
                 :body
                 (json/parse-string true)
                 :docs)]
    (sb/generate
      (map #(sb/add-hash (assoc % :type "document")) docs))))

(main *command-line-args*)
