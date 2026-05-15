/// job_repository_impl.dart
///
/// Concrete implementation of [JobRepository].
/// Translates datasource exceptions → domain [Failure] objects,
/// so the presentation layer never sees raw http or parse exceptions.

import 'package:dartz/dartz.dart';

import '../../domain/models/job_listing_model.dart';
import '../../domain/repositories/job_repository.dart';
import '../datasources/job_remote_datasource.dart';

class JobRepositoryImpl implements JobRepository {
  const JobRepositoryImpl({required JobRemoteDatasource datasource})
      : _datasource = datasource;

  final JobRemoteDatasource _datasource;

  // ── searchJobs ────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, ScrapedJobResponse>> searchJobs(
    SearchJobsParams params,
  ) async {
    try {
      final result = await _datasource.searchJobs(params);
      return Right(result);
    } on JobServiceException catch (e) {
      return Left(JobServiceFailure(e.message));
    } catch (e) {
      return Left(JobServiceFailure('Unexpected error during job search: $e'));
    }
  }

  // ── getJobById ────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, JobListingModel>> getJobById(String id) async {
    try {
      final result = await _datasource.getJobById(id);
      return Right(result);
    } on JobNotFoundException catch (e) {
      return Left(JobNotFoundFailure(e.toString()));
    } on JobServiceException catch (e) {
      return Left(JobServiceFailure(e.message));
    } catch (e) {
      return Left(JobServiceFailure('Unexpected error fetching job $id: $e'));
    }
  }

  // ── checkScam ─────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, ScamCheckResponse>> checkScam(String jobId) async {
    try {
      final result = await _datasource.checkScam(jobId);
      return Right(result);
    } on JobNotFoundException catch (e) {
      return Left(JobNotFoundFailure(e.toString()));
    } on JobServiceException catch (e) {
      return Left(JobServiceFailure(e.message));
    } catch (e) {
      return Left(JobServiceFailure('Unexpected error during scam check: $e'));
    }
  }
}
