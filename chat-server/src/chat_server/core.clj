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
    [clojure.data.json :as json]))

;; user handling
(def connections-to-users (atom {}))
(def chatrooms (bus/event-bus))

(defn add-user 
  [users new-connection]
  (assoc users new-connection {:name "new-user"}))
(defn add-user! 
  [new-connection]
  (swap! connections-to-users add-user new-connection))
(defn rename-user
  [users target-user new-name]
  (if (contains? users target-user)
    (update-in users [target-user :name] (fn [& _] new-name))
    users)
    )
(defn rename-user!
  [target-user new-name]
  (swap! connections-to-users rename-user target-user new-name))
(defn remove-user!
  [target-user]
  (swap! connections-to-users dissoc target-user))

(defn get-name-for-user
  [target-user]
  (if (contains? @connections-to-users target-user)
    ((@connections-to-users target-user) :name)
    nil))

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

(defn echo-handler
  [req]
  (->
    (d/let-flow [socket (http/websocket-connection req)
                  _ (s/on-closed socket #(println "socket closed"))]
      
      (s/connect socket socket))
    (d/catch
      (fn [_]
        non-websocket-request))))

;; action handlers
(defn handle-action-send-message
  [payload conn]
  (if (and (contains? payload :message) (contains? payload :target-channel))
    (bus/publish! chatrooms (payload :target-channel) (str (get-name-for-user conn) " said " (payload :message)))
    (reply-error conn "send-message action payload didn't have message and/or room!")))

(defn handle-action-change-name
  [payload conn]
  (if (contains? payload :new-name)
    (rename-user! conn (payload :new-name)) 
    (reply-error conn "change-name action payload didn't include new-name!")))

(defn handle-action-join-channel
  [payload conn]
  (if (contains? payload :target-channel)
    (let [channel (payload :target-channel)]
      (s/connect (bus/subscribe chatrooms channel) conn)
    )
    (reply-error conn "join-channel action payload didn't include target-channel!")))

(defn handle-action-get-channel-users
  [payload conn]
  (if (contains? payload :target-channel)
    ;; this is not pretty. s/downstream returns a list of [description stream] pairs and the stream there is our user
    (let [users (map (fn [stream] (get-name-for-user (second (first (s/downstream stream))))) (bus/downstream chatrooms (payload :target-channel)))]
      (send-response conn "channel-users" {:channel (payload :target-channel) :users users}))
    (reply-error conn "change-name action payload didn't include new-name!")))

(defn get-channels-info
  [target-bus]
  (map #(hash-map :name (key %) :user-count (count (val %))) (bus/topic->subscribers target-bus)))

(defn handle-action-get-channels-info
  [_ conn]
  (send-response conn "channels-info" {:info (get-channels-info chatrooms)}))


(def action-mapping {
  "send-message" handle-action-send-message
  "change-name" handle-action-change-name
  "join-channel" handle-action-join-channel
  "get-channel-users" handle-action-get-channel-users
  "get-channels-info" handle-action-get-channels-info
})

(defn handle-incoming-data
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
                    _ (s/on-closed conn #(remove-user! conn))]
        
        (s/consume
          #(handle-incoming-data room conn %)
          (->> conn
              (s/map #(str %))
              (s/buffer 100))))))

    quit-response)


(def handler
  (params/wrap-params
    (compojure/routes
      (GET "/chat" [] chat-handler)
      (GET "/echo" [] echo-handler)
      (route/not-found "No such page."))))


(defn -main
  "I don't do a whole lot ... yet."
  [& args]
  (println "Starting server!")
  (http/start-server handler {:port 10000})
  (println "Server running?")
  )


