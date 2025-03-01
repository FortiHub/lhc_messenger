import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/subjects.dart';

import 'package:livehelp/model/model.dart';


class LocalNotificationPlugin {
  //
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  final BehaviorSubject<ReceivedNotification>
      didReceivedLocalNotificationSubject =
      BehaviorSubject<ReceivedNotification>();
  var initializationSettings;

  LocalNotificationPlugin._() {
    init();
  }

  init() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    if (Platform.isIOS) {
      _requestIOSPermission();
    } else {

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'com.livehelperchat.chat.channel.NEWCHAT', // id
        'New chat (background)', // title
        'New chat notifications while app is in the background', // description
        importance: Importance.High,
        enableVibration: true,
        playSound: true,
      );

      const AndroidNotificationChannel channelMessage = AndroidNotificationChannel(
        'com.livehelperchat.chat.channel.NEWMESSAGE', // id
        'New messages (background)', // title
        'New chat messages notifications while app is in the background', // description
        importance: Importance.High,
        enableVibration: true,
        playSound: true,
      );

      const AndroidNotificationChannel channelGroupMessage = AndroidNotificationChannel(
        'com.livehelperchat.chat.channel.NEWGROUPMESSAGE', // id
        'New group messages (background)', // title
        'New group messages notifications while app is in the background', // description
        importance: Importance.High,
        enableVibration: true,
        playSound: true,
      );

      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channelMessage);

      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channelGroupMessage);
    }

    initializePlatformSpecifics();
  }

  // default channel id - same as in AndroidManifest.xml file
  static final NotificationChannel channelDefault = NotificationChannel(
      id: "com.livehelperchat.chat.channel.lhcmessenger_notification",
      name: "Default",
      description: "Default notifications while app is open",
      number: 1001);

  static final NotificationChannel silentChannel = NotificationChannel(
      id: "com.livehelperchat.chat.channel.lhc_silent_channel",
      name: "Default",
      description: "Default notifications while app is open",
      number: 1001);

  static final NotificationChannel channelNewChat = NotificationChannel(
      id: "com.livehelperchat.chat.channel.NEWCHAT",
      name: "New chat (open app)",
      description: "New chat notifications while app is open",
      number: 1111);

  static final NotificationChannel channelNewMsg = NotificationChannel(
      id: "com.livehelperchat.chat.channel.NEWMESSAGE",
      name: "New messages (open app)",
      description: "New messages notifications while app is open",
      number: 2222);

  static final NotificationChannel channelUnreadMsg = NotificationChannel(
      id: "com.livehelperchat.chat.channel.UNREADMSG",
      name: "Unread messages (open app)",
      description: "Unread messages notifications while app is open",
      number: 3333);

  static final NotificationChannel channelNewGroupMsg = NotificationChannel(
      id: "com.livehelperchat.chat.channel.NEWGROUPMESSAGE",
      name: "New group messages (open app)",
      description: "New group messages notifications while app is open",
      number: 4444);

  initializePlatformSpecifics() {
    var initializationSettingsAndroid = AndroidInitializationSettings('icon');
    var initializationSettingsIOS = IOSInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        ReceivedNotification receivedNotification = ReceivedNotification(
            id: id, title: title, body: body, payload: payload);
        didReceivedLocalNotificationSubject.add(receivedNotification);
      },
    );
    initializationSettings = InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
  }

  _requestIOSPermission() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        .requestPermissions(
          alert: false,
          badge: true,
          sound: true,
        );
  }

  void _createDefaultNotificationChannel() async {
    //Create Default Android channel
    var defaultAndroidNotificationChannel = AndroidNotificationChannel(
      channelDefault.id,
      channelDefault.name,
      channelDefault.description,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(defaultAndroidNotificationChannel);
  }

  setListenerForLowerVersions(Function onNotificationInLowerVersions) {
    didReceivedLocalNotificationSubject.listen((receivedNotification) {
      onNotificationInLowerVersions(receivedNotification);
    });
  }

  setOnNotificationClick(Function onNotificationClick) async {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: (String payload) async {
      onNotificationClick(payload);
    });

    _createDefaultNotificationChannel();
  }

  showNotification(ReceivedNotification notification) async {
    NotificationChannel channel;
    //String title="";
    switch (notification.type) {
      case NotificationType.NEW_MESSAGE:
        channel = channelNewMsg;
        break;
      case NotificationType.NEW_GROUP_MESSAGE:
        channel = channelNewGroupMsg;
        break;
      case NotificationType.PENDING:
        channel = channelNewChat;
        break;
      case NotificationType.UNREAD:
        channel = channelUnreadMsg;
        break;
      default:
        break;
    }

    if (notification.server?.isLoggedIn ?? false) {
      displayNotification(channel, notification,
          playSound: notification.server.soundnotify == 0);
    }
  }

  void displayNotification(
      NotificationChannel channel, ReceivedNotification notification,
      {bool playSound = true}) async {
    String channelId, channelName, channelDescription;
    if (playSound) {
      channelId = channel.id;
      channelName = channel.name;
      channelDescription = channel.description;
    } else {
      channelId = LocalNotificationPlugin.silentChannel.id;
      channelName = channel.name;
      channelDescription = channel.description;
    }

    var vibrationPattern = new Int64List(3);
    vibrationPattern[0] = 0;
    vibrationPattern[1] = 100;
    vibrationPattern[2] = 1000;
    // vibrationPattern[3] = 1000;
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        channelId, channelName, channelDescription,
        icon: 'icon',
        importance: Importance.High,
        priority: Priority.High,
        playSound: playSound,
        sound: RawResourceAndroidNotificationSound('slow_spring_board'),
        styleInformation: DefaultStyleInformation(true, true));
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    NotificationDetails platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(channel.number,
        notification.title, notification.body, platformChannelSpecifics,
        payload: jsonEncode(notification.toJson()));
  }

  static Future<dynamic> backgroundMessageHandler(
      Map<String, dynamic> message) {

    if (message.containsKey('data')) {
      // Handle data message
      final dynamic data = message['data'];
    }

    if (message.containsKey('notification')) {
      // Handle notification message
      final dynamic notification = message['notification'];
    }

    return Future<void>.value();
  }

  Future<int> getPendingNotificationCount() async {
    List<PendingNotificationRequest> p =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return p.length;
  }

  Future<void> cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancel(0);
  }

  Future<void> cancelAllNotification() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}

LocalNotificationPlugin notificationPlugin = LocalNotificationPlugin._();

class ReceivedNotification {
  int id;
  Chat chat;
  User gchat;
  Server server;
  NotificationType type;
  final String title;
  final String body;
  String payload;
  ReceivedNotification({
    @required this.title,
    @required this.body,
    this.server,
    this.id,
    this.type,
    this.chat,
    this.gchat,
    this.payload,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'server': server?.toJson(),
        'title': title,
        'body': body,
        'payload': payload,
        'type': type.toString(),
        'chat': chat?.toJson(),
        'gchat': gchat?.toJson()
      };

  ReceivedNotification.fromJson(Map<String, dynamic> map)
      : id = map['id'] ?? 0,
        body = map['body'] ?? '',
        title = map['title'] ?? 'Title not specified',
        payload = map['payload'] ?? '' {
    type = getNotificationTypeFromString(map['type'].toString()) ??
        NotificationType.INFO;
    server = Server.fromJson(map['server']) ?? null;
    chat = map.containsKey('chat') && map['chat'] != null ? Chat.fromJson(map['chat']) : null;
    gchat = map.containsKey('gchat') && map['gchat'] != null ? User.fromJson(map['gchat']) : null;
  }

  NotificationType getNotificationTypeFromString(String typeStr) {
    return NotificationType.values
        .firstWhere((nt) => nt.toString() == typeStr, orElse: () => null);
  }
}

enum NotificationType { INFO, NEW_MESSAGE, PENDING, UNREAD, NEW_GROUP_MESSAGE }
