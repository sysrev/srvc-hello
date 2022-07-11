#!/usr/bin/env bb

(require '[babashka.deps :as deps])

(deps/add-deps '{:deps {co.insilica/bb-srvc {:mvn/version "0.4.0"}}})

(require '[srvc.bb :as sb])

(sb/map
 (fn [_ event]
   (prn event)
   [event]))
