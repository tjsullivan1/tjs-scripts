@{
    ExcludeRules = @(
        # These helpers create or update in-memory records and do not change external system state.
        'PSUseShouldProcessForStateChangingFunctions'

        # These internal functions intentionally use plural names because they return collections.
        'PSUseSingularNouns'
    )
}
