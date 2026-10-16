@{
    ExcludeRules = @(
        # These helpers create or update in-memory records and do not change external system state.
        'PSUseShouldProcessForStateChangingFunctions'

        # The analyzer cannot see nested-function dynamic-scope usage or mock proxy parameters.
        'PSReviewUnusedParameter'

        # These internal functions intentionally use plural names because they return collections.
        'PSUseSingularNouns'
    )
}
