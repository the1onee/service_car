import 'package:barrr/models/job.dart';

bool jobIsDone(Job job) =>
    job.status == JobStatus.completed || job.status == JobStatus.rated;

bool jobIsClosed(Job job) => job.status == JobStatus.cancelled;

bool jobIsOpen(Job job) => !jobIsDone(job) && !jobIsClosed(job);

/// طلب مُسند يمنع ظهور عروض جديدة للفني الميداني.
bool jobBlocksIncomingOffers(Job? job) {
  if (job == null) return false;
  switch (job.status) {
    case JobStatus.enRoute:
    case JobStatus.arrived:
    case JobStatus.finalQuote:
    case JobStatus.inProgress:
      return true;
    default:
      return false;
  }
}

String jobCode(Job job) {
  final raw = job.id.replaceAll('-', '');
  final tail = raw.length <= 6 ? raw : raw.substring(0, 6);
  return '#${tail.toUpperCase()}';
}
