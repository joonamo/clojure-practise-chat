(ns chat-server.users
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
  (:use chat-server.responses))

;; user handling
(def connections-to-users (atom {}))

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
  "notifies other channel users about user leaving"
  [channel user]
  (if (nil? channel)
    nil
    (send-to-channel channel "user-leave" {:user user :channel channel })))

(defn notify-leave-channel-all
  "Takes all user channels and notifies them about user leaving"
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