/// job_repository.dart — Abstract repository contract for the jobs feature.
///
/// All methods return [Either<Failure, T>] following clean architecture:
///   - Left(Failure)  → an error occurred (network, parse, not-found)
///   - Right(T)       → success

import 'package:dartz/dartz.dart';
import '../models/job_listing_model.dart';

// ─── Failure types ─────────────────────────────────────────────────────────────

sealed class Failure {
  const Failure(this.message);
  final String message;
}

/// The job scraper microservice is unreachable or returned an unexpected error.
class JobServiceFailure extends Failure {
  const JobServiceFailure(super.message);
}

/// A specific job ID was not found in the scraper's in-memory store.
class JobNotFoundFailure extends Failure {
  const JobNotFoundFailure(super.message);
}

/// The response body could not be parsed into the expected model.
class ParseFailure extends Failure {
  const ParseFailure(super.message);
}

// ─── Repository interface ──────────────────────────────────────────────────────

abstract class JobRepository {
  /// Search for jobs matching the given parameters.
  /// Calls  POST /jobs/search  on the microservice.
  Future<Either<Failure, ScrapedJobResponse>> searchJobs(SearchJobsParams params);

  /// Fetch the full detail of a single job by its ID (sha256 hash).
  /// Calls  GET /jobs/{id}  on the microservice.
  Future<Either<Failure, JobListingModel>> getJobById(String id);

  /// Run the scam-check analysis on an already-scraped job by its ID.
  /// Calls  POST /jobs/scam-check  on the microservice.
  Future<Either<Failure, ScamCheckResponse>> checkScam(String jobId);
}
