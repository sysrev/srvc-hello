#!/usr/bin/env bb

(require '[babashka.deps :as deps])

(deps/add-deps '{:deps {co.insilica/bb-srvc {:mvn/version "0.8.0"}}})

(require '[srvc.bb.html :as bhtml])

(bhtml/serve (bhtml/resource-path *file*) "public/label.html")
