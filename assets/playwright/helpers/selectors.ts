// Selector constants found by Claude, make sure to double check when using

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

// Displayed validation strings (confirmed live). The red error flash uses the
// error_formatter wording, which matches the regression doc. For an empty
// Subway/Station-issue form the flash shows the title plus "Select stop(s)".
export const VALIDATION = {
    errorFlashTitle: 'Please fix the following errors:',
    subwayStop: 'Select stop(s)',
};