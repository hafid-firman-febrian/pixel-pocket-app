import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/features/transactions/data/repositories/transaction_repository.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_filter.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';

class TransactionService {
  TransactionService(this._repo);

  final TransactionRepository _repo;

  Future<List<TransactionModel>> list(TransactionFilter filter) =>
      _repo.getAll(filter);

  Future<TransactionModel> getById(int id) => _repo.getById(id);

  Future<TransactionModel> create({
    required String transactionDate,
    required String transactionType,
    required double amount,
    int? categoryId,
    String? description,
    int? accountId,
  }) {
    final transaction = TransactionModel(
      id: 0,
      transactionDate: transactionDate,
      transactionType: transactionType,
      amount: amount,
      categoryId: categoryId,
      description: description,
      accountId: accountId,
    );
    return _repo.create(transaction);
  }

  Future<TransactionModel> update({
    required int id,
    required String transactionDate,
    required String transactionType,
    required double amount,
    int? categoryId,
    String? description,
    int? accountId,
  }) {
    final transaction = TransactionModel(
      id: id,
      transactionDate: transactionDate,
      transactionType: transactionType,
      amount: amount,
      categoryId: categoryId,
      description: description,
      accountId: accountId,
    );
    return _repo.update(transaction);
  }

  Future<TransactionModel> createTransfer({
    required String transactionDate,
    required double amount,
    required int? fromAccountId,
    required int? toAccountId,
    double fee = 0,
    String? description,
  }) async {
    _validateTransfer(
      amount: amount,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      fee: fee,
    );
    return _repo.createTransfer(
      _transfer(
        id: 0,
        transactionDate: transactionDate,
        amount: amount,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        description: description,
      ),
      fee: fee,
    );
  }

  Future<TransactionModel> updateTransfer({
    required int id,
    required String transactionDate,
    required double amount,
    required int? fromAccountId,
    required int? toAccountId,
    double fee = 0,
    String? description,
  }) async {
    _validateTransfer(
      amount: amount,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      fee: fee,
    );
    return _repo.updateTransfer(
      _transfer(
        id: id,
        transactionDate: transactionDate,
        amount: amount,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        description: description,
      ),
      fee: fee,
    );
  }

  Future<void> delete(int id) => _repo.delete(id);

  TransactionModel _transfer({
    required int id,
    required String transactionDate,
    required double amount,
    required int? fromAccountId,
    required int? toAccountId,
    String? description,
  }) =>
      TransactionModel(
        id: id,
        transactionDate: transactionDate,
        transactionType: 'transfer',
        amount: amount,
        accountId: fromAccountId,
        toAccountId: toAccountId,
        description: description,
      );

  void _validateTransfer({
    required double amount,
    required int? fromAccountId,
    required int? toAccountId,
    required double fee,
  }) {
    if (fromAccountId == null) {
      throw const Failure(message: 'Select the account to transfer from.');
    }
    if (toAccountId == null) {
      throw const Failure(message: 'Select the account to transfer to.');
    }
    if (fromAccountId == toAccountId) {
      throw const Failure(message: 'Choose two different accounts.');
    }
    if (amount <= 0) {
      throw const Failure(message: 'Enter a valid amount.');
    }
    if (fee < 0) {
      throw const Failure(message: 'Admin fee cannot be negative.');
    }
  }
}

final transactionServiceProvider = Provider<TransactionService>(
  (ref) => TransactionService(ref.watch(transactionRepositoryProvider)),
);
