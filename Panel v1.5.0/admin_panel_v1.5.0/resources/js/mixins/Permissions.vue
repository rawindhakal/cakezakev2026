<script>
export default {
    methods: {
        $can(permissionName) {
            return UserPermissions.indexOf(permissionName) !== -1;
        },
        $role(roleName) {
            return Role === roleName;
        },
        $isBranchUser() {
            return typeof window !== 'undefined' && window.BranchZoneId != null;
        },
        // The branch OWNER (primary login) — distinct from delegated sub-users.
        $isBranchOwner() {
            return typeof window !== 'undefined' && window.IsBranchOwner === true;
        },
    },
};
</script>
