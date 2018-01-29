(ns chat-server.core
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
    [clj-uuid :as uuid])
  (:use 
    chat-server.actions
    chat-server.responses
    chat-server.users))

(def action-mapping {
  "send-message" handle-action-send-message
  "change-name" handle-action-change-name
  "join-channel" handle-action-join-channel
  "get-channel-users" handle-action-get-channel-users
  "get-channels-info" handle-action-get-channels-info
})

(defn handle-incoming-data
  "Handles data from client"
  [room conn data]
  (println (str "data: " data))
  (let [command (try
    (json/read-str (str data) :key-fn keyword)
    (catch Exception e nil))] 

    (println (str "command: " command))
    (if command
      ;; We found at least some kind of json!
      (let [handler 
        (get action-mapping (command :action) 
        (fn [& _] (reply-error conn (str "Unknown command: " (command :action)))))
        ]

        (handler (command :payload) conn)
      )
      ;; Doesn't seem like json, error!
      (reply-error conn "Malformed json!")
    )
  )
)

(defn chat-handler
  "Handles initial connection"
  [req]
    (d/let-flow [conn (d/catch
                      (http/websocket-connection req)
                      (fn [_] nil))]
    (if-not conn
      ;; if it wasn't a valid websocket handshake, return an error
      non-websocket-request
      ;; otherwise, create new user
      (d/let-flow [room "default"
                    _ (add-user! conn)
                    _ (s/on-closed conn #(handle-user-leave conn))]
        (send-response conn "welcome" {:user (get-name-and-id-for-user conn)})
        (s/consume
          #(handle-incoming-data room conn %)
          (->> conn
              (s/map #(str %))
              (s/buffer 100))))))

    quit-response)


(def handler
  "Routes http requests, currently only /chat is allowed path"
  (params/wrap-params
    (compojure/routes
      (GET "/chat" [] chat-handler)
      (route/not-found "No such page."))))


(defn -main
  "Starts the server"
  [& args]
  (println "Starting server!")
  (http/start-server handler {:port 10000})
  (println "Server running?")
  )


