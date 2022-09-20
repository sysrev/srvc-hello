#!/usr/bin/env bb

(def notebook "srvc.ipynb")

(when-not (fs/exists? notebook)
  (->> {:cells [] :metadata {} :nbformat 4 :nbformat_minor 2}
       json/generate-string
       (spit notebook)))

@(babashka.process/process
  ["jupyter" "notebook" notebook]
  {:inherit true
   :shutdown babashka.process/destroy-tree})
