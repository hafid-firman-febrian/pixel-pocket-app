import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/features/transactions/data/datasources/transaction_dao.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_filter.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';

class TransactionRepository {
  TransactionRepository(this._dao);

  final TransactionDao _dao;

  Future<List<TransactionModel>> getAll(TransactionFilter filter) =>
      _dao.getAll(filter);

  Future<TransactionModel> getById(int id) => _dao.getById(id);

  Future<TransactionModel> create(TransactionModel transaction) =>
      _dao.create(transaction);

  Future<TransactionModel> update(TransactionModel transaction) =>
      _dao.update(transaction);

  Future<TransactionModel> createTransfer(
    TransactionModel transfer, {
    double fee = 0,
  }) =>
      _dao.createTransfer(transfer, fee: fee);

  Future<TransactionModel> updateTransfer(
    TransactionModel transfer, {
    double fee = 0,
  }) =>
      _dao.updateTransfer(transfer, fee: fee);

  Future<void> delete(int id) => _dao.delete(id);
}

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(transactionDaoProvider)),
);
