import 'dart:async';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:ff/models/RealtimeUpdates.dart';
import 'package:ff/services/backend_api.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class MessageBloc extends Object with ChangeNotifier {
  MessageBloc({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;
  final _messagesController = BehaviorSubject<List<Message>>.seeded([]);
  final _meessageController = BehaviorSubject<String>();

  Stream<List<Message>> get messages => _messagesController.stream;
  Stream<String> get message => _meessageController.stream;

  Function(String) get changeMessage => _meessageController.sink.add;

  // fetch all group messages, chat messages for user id,
  // sperate entry contacts -> all Ids
  Future<void> fetchMessages({String? fromId, String? toId}) async {
    try {
      final messages =
          await _apiClient.fetchMessages(fromId: fromId, toId: toId);
      _messagesController.add(messages);
    } on BackendApiException catch (e) {
      _messagesController.addError(e.message);
    }
  }

  void applyRealtimeChat(RealtimeChatUpdate update) {
    _messagesController.add(update.messages);
  }

  Future<void> sendMessage(String msg, String fromId, String toId) async {
    try {
      await _apiClient.sendMessage(content: msg, fromId: fromId, toId: toId);
      await fetchMessages(fromId: fromId, toId: toId);
    } on BackendApiException catch (e) {
      _messagesController.addError(e.message);
    }
  }

  Future<ContentReportResult?> reportMessage({
    required String playerId,
    required String messageId,
    required String reason,
  }) async {
    try {
      return await _apiClient.reportMessage(
        playerId: playerId,
        messageId: messageId,
        reason: reason,
      );
    } on BackendApiException catch (e) {
      _messagesController.addError(e.message);
      return null;
    } on Exception {
      _messagesController.addError('Could not submit content report.');
      return null;
    }
  }

  @override
  void dispose() {
    _messagesController.close();
    _meessageController.close();
    _apiClient.close();
    super.dispose();
  }
}
