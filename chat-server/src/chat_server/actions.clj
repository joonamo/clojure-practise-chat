(ns chat-server.actions
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
    chat-server.users
    chat-server.responses))

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
      ;; only allow user to join channel once
      (if-not (contains? ((@connections-to-users conn) :channels) channel)
        (let [_ nil]
          (add-user-channel! conn channel)
          (send-to-channel channel "user-join" {:user(get-name-and-id-for-user conn) :channel channel})
          (s/connect (bus/subscribe chatrooms channel) conn)))
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
