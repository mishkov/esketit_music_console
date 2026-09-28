enum CatalogPublicationStatus {
  published('published', 'Published'),
  pendingReview('pending_review', 'Pending review'),
  changesRequested('changes_requested', 'Changes requested');

  const CatalogPublicationStatus(this.code, this.label);

  final String code;
  final String label;

  static CatalogPublicationStatus fromJson(Object? value) {
    return values.firstWhere(
      (status) => status.code == value,
      orElse: () => CatalogPublicationStatus.published,
    );
  }
}
