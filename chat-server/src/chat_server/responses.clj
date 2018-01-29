(ns chat-server.responses
  (:require
    [compojure.core :as compojure :refer [GET]]
    [ring.middleware.params :as params]
    [compojure.route :as route]
    [aleph.http :as http]
    [byte-streams :as bs]
    [manifold.stream :as s]
    [manifold.deferred :as d]
    [manifold.bus :as bus]
    [clojure.core.async :as a]
    [clojure.data.json :as json]
    [clj-uuid :as uuid]))

;; Event bus for users to subscribe to
(def chatrooms (bus/event-bus))

;; default responses
(def non-websocket-request
  {:status 400
   :headers {"content-type" "application/text"}
   :body "Expected a websocket request."})

(def quit-response
  {:status 200
   :headers {"content-type" "application/text"}
   :body "Thank you for chatting!"})

;; responses to socket
(defn json-response
  [type payload]
  (json/write-str {:type type :payload payload}))

(defn send-response
  [conn type payload]
  (s/put! conn (json-response type payload)))

(defn error-json-response
  [desc]
  (json-response "Error" {:description (str desc)})
)

(defn reply-error
  [conn message]
  (s/put! conn (error-json-response (str message))))

(defn send-to-channel
  [channel type payload]
  (let [response (json-response type payload)]
    (println (str "send-to-channel " response))
    (bus/publish! chatrooms channel response)))