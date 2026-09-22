import 'package:barrr/models/job.dart';

bool jobIsDone(Job job) =>
    job.status == JobStatus.completed || job.status == JobStatus.rated;

bool jobIsClosed(Job job) =>
    job.status == JobStatus.cancelled || job.status == JobStatus.noTechnician;

bool jobIsOpen(Job job) => !jobIsDone(job) && !jobIsClosed(job);

String jobCode(Job job) {
  final raw = job.id.replaceAll('-', '');
  final tail = raw.length <= 6 ? raw : raw.substring(0, 6);
  return '#${tail.toUpperCase()}';
}
