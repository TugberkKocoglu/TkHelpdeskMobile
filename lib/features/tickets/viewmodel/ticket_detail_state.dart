import 'package:equatable/equatable.dart';

import '../models/ticket_comment_model.dart';
import '../models/ticket_detail_model.dart';

enum TicketDetailStatus { initial, loading, success, failure }

class TicketDetailState extends Equatable {
  const TicketDetailState({
    this.status = TicketDetailStatus.initial,
    this.detail,
    this.comments = const [],
    this.isProcessing = false,
    this.errorMessage,
    this.actionError,
    this.successMessage,
    this.actionVersion = 0,
    this.dataVersion = 0,
  });

  final TicketDetailStatus status;
  final TicketDetailModel? detail;
  final List<TicketCommentModel> comments;
  final bool isProcessing;
  final String? errorMessage;
  final String? actionError;
  final String? successMessage;

  // Her işlem sonucunda dinleyiciye yeni olay bildirir.
  final int actionVersion;

  // Veri değiştiğinde liste ekranının yenilenebilmesi için.
  final int dataVersion;

  TicketDetailState copyWith({
    TicketDetailStatus? status,
    TicketDetailModel? detail,
    List<TicketCommentModel>? comments,
    bool? isProcessing,
    String? errorMessage,
    String? actionError,
    String? successMessage,
    bool clearActionMessages = false,
    int? actionVersion,
    int? dataVersion,
  }) {
    return TicketDetailState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      comments: comments ?? this.comments,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
      actionError:
          actionError ?? (clearActionMessages ? null : this.actionError),
      successMessage:
          successMessage ?? (clearActionMessages ? null : this.successMessage),
      actionVersion: actionVersion ?? this.actionVersion,
      dataVersion: dataVersion ?? this.dataVersion,
    );
  }

  @override
  List<Object?> get props => [
    status,
    detail,
    comments,
    isProcessing,
    errorMessage,
    actionError,
    successMessage,
    actionVersion,
    dataVersion,
  ];
}
