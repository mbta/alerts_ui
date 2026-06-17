// Verified selector constants (live-DOM ground truth, 2026-06-17).
// Sources: view_alerts_live.html.heex, core_components.ex, filter_form.ex,
// url_slice.ex, affected_service_slice.ex, alert_details_slice.ex,
// submit_slice.ex, review_modal.ex, error_formatter.ex.
// No data-testid exists in the app — rely on roles/labels/ids below.

export const LIST = {
  // Timeline tabs are radio inputs (aria-label), NOT ARIA tabs.
  tabCurrent: 'Current',
  tabFuture: 'Future',
  tabPast: 'Past',
  tabAll: 'All',
  // Filters button reads "Filter" (0 active) or "Filters: N".
  filtersButton: /^Filter/,
  filterModalId: '#alerts-filter-modal',
  applyButton: 'Apply',
  // Search is debounced (750ms) on change — no Enter submission.
  searchPlaceholder: 'Search alerts',
  emptyState: 'No alerts found',
  createButton: 'Create new alert',
  detailsModalId: '#review-modal',
};

export const SERVICE_TYPES = ['Bus', 'Subway', 'Commuter Rail', 'Ferry', 'Facility', 'Systemwide'] as const;

export const SUBWAY_LINES = [
  'Red Line', 'Orange Line', 'Green Line', 'Green Line B', 'Green Line C',
  'Green Line D', 'Green Line E', 'Blue Line',
] as const;

export const CREATE = {
  reviewButtonId: '#review',
  reviewAndSubmit: /review and submit/i,
  keepEditing: /keep editing/i,
  submit: /^submit$/i,
  causeLabel: 'Cause',
  severityLabel: 'Severity',
  mainMessageLabel: 'Main message',
  directionLabel: 'Direction',
  stopsLabel: 'Stops',
  notificationToggleId: '#notification-toggle',
  defaultSeverity: 'about 15 minutes',
};

// ACTUAL enforced validation strings (differ from regression doc — see spec).
// Doc claims "Select route(s)/stop(s)"; the app emits these:
export const VALIDATION = {
  errorFlashTitle: 'Please fix the following errors:',
  subwayRoute: 'You must select a route',
  subwayStop: 'You must select a stop',
};
