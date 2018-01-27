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
    [clj-uuid :as uuid]))

(declare send-to-channel)

;; user handling
(def connections-to-users (atom {}))
(def chatrooms (bus/event-bus))

(defn get-name-for-user
  [target-user]
  (if (contains? @connections-to-users target-user)
    ((@connections-to-users target-user) :name)
    nil))

(defn get-id-for-user
  [target-user]
  (if (contains? @connections-to-users target-user)
    ((@connections-to-users target-user) :id)
    (uuid/v0)))

(defn get-name-and-id-for-user
  "id will be returned as string for safe jsonifying"
  [target-user]
  {:name (get-name-for-user target-user) :id (str (get-id-for-user target-user))})

(defn add-user 
  [users new-connection]
  (assoc users new-connection {:name "new-user" :channels #{} :id (uuid/v4)}))
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

(defn add-user-channel
  [users target-user new-channel]
  (if (contains? users target-user)
    (update-in users [target-user :channels] #(conj % new-channel))
    users)
)
(defn add-user-channel!
  [target-user new-channel]
  (swap! connections-to-users add-user-channel target-user new-channel))

(defn remove-user!
  [target-user]
  (swap! connections-to-users dissoc target-user))

(defn notify-leave-channel
  [channel user]
  (if (nil? channel)
    nil
    (send-to-channel channel "user-leave" {:user user :channel channel })))

(defn notify-leave-channel-all
  [channels user]
  (notify-leave-channel (first channels) user)
  (if (empty? channels)
    nil
    (recur (rest channels) user)))

(defn handle-user-leave
  [target-user]
  (println (str "user leaving " target-user))
  (if (contains? @connections-to-users target-user)
    (let [channels ((@connections-to-users target-user) :channels)]
      (notify-leave-channel-all channels (get-name-and-id-for-user target-user))) 
    (println "unknown user"))
  (remove-user! target-user))

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
  (let [message (payload :message)
        target-channel (payload :target-channel)]
  (if (and message target-channel)
    (send-to-channel target-channel "message" 
      {:user (get-name-and-id-for-user conn) :channel target-channel :message message})
    (reply-error conn "send-message action payload didn't have message and/or target-channel!"))))

(defn notify-channel-user-rename
  [channel user-id old-name new-name]
  (if (nil? channel)
    nil
    (send-to-channel channel "user-rename" 
      {:user {:name old-name :id user-id} :new-name new-name :old-name old-name})))

(defn notify-user-rename
  [channels user-id old-name new-name]
  (notify-channel-user-rename (first channels) user-id old-name new-name)
  (if (empty? channels)
    nil
    (recur (rest channels) user-id old-name new-name)))

(defn handle-action-change-name
  [payload conn]
  (if (contains? payload :new-name)
    (let [user (get-name-and-id-for-user conn)
          new-name (payload :new-name)
          channels ((@connections-to-users conn) :channels)]
        (rename-user! conn new-name)
        (notify-user-rename channels (user :id) (user :name) new-name)) 
    (reply-error conn "change-name action payload didn't include new-name!")))

(defn handle-action-join-channel
  [payload conn]
  (if (contains? payload :target-channel)
    (let [channel (payload :target-channel)]
      (add-user-channel! conn channel)
      (send-to-channel channel "user-join" {:user(get-name-and-id-for-user conn) :channel channel})
      (s/connect (bus/subscribe chatrooms channel) conn)
    )
    (reply-error conn "join-channel action payload didn't include target-channel!")))

(defn handle-action-get-channel-users
  [payload conn]
  (if (contains? payload :target-channel)
    ;; this is not pretty. s/downstream returns a list of [description stream] pairs and the stream there is our user
    (let [users (map 
      (fn [stream] (get-name-and-id-for-user (second (first (s/downstream stream))))) 
      (bus/downstream chatrooms (payload :target-channel)))]
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
                    _ (s/on-closed conn #(handle-user-leave conn))]
        
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


