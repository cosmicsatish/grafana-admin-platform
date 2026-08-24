package main

# 1. Deny service accounts with global Admin org role
deny[msg] {
    sa := input.serviceAccounts[_]
    sa.role == "Admin"
    msg := sprintf("Security Violation: Service account '%v' cannot have global role 'Admin'. Use base role 'None' with specific fixedRoles instead.", [sa.name])
}

# 2. Deny service accounts with global Editor org role (recommend None + fixedRoles)
deny[msg] {
    sa := input.serviceAccounts[_]
    sa.role == "Editor"
    msg := sprintf("Security Violation: Service account '%v' cannot have global role 'Editor'. Use base role 'None' with specific fixedRoles instead.", [sa.name])
}

# 3. Enforce token expiry on service accounts
deny[msg] {
    sa := input.serviceAccounts[_]
    sa.tokenExpires == ""
    msg := sprintf("Compliance Violation: Service account '%v' must specify a valid token expiration date.", [sa.name])
}

# 4. Require folder UIDs and titles
deny[msg] {
    folder := input.folders[_]
    not folder.uid
    msg := sprintf("Schema Violation: Folder with title '%v' is missing a required stable UID.", [folder.title])
}

# 5. Require team name and slug
deny[msg] {
    team := input.teams[_]
    not team.slug
    msg := sprintf("Schema Violation: Team '%v' is missing a required slug identifier.", [team.name])
}
