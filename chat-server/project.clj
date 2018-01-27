(defproject chat-server "0.1.0-SNAPSHOT"
  :description "FIXME: write description"
  :url "http://example.com/FIXME"
  :license {:name "Eclipse Public License"
            :url "http://www.eclipse.org/legal/epl-v10.html"}
  :dependencies [
  [org.clojure/clojure "1.8.0"]
  [aleph "0.4.4"]
  [compojure "1.6.0"]
  [org.clojure/core.async "0.4.474"]
  [org.clojure/data.json "0.2.6"]
  [danlentz/clj-uuid "0.1.7"]]
  :main ^:skip-aot chat-server.core
  :target-path "target/%s"
  :profiles {:uberjar {:aot :all}})
