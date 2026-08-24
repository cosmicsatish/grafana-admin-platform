#!/usr/bin/env python3
"""
Automated Resource Onboarding & Management Tool
Allows adding, updating, and removing Grafana platform resources
without manually editing YAML files.
"""

import argparse
import pathlib
import sys
import yaml

ROOT_DIR = pathlib.Path(__file__).resolve().parent.parent
VALUES_DIR = ROOT_DIR / "chart" / "values"


def load_yaml(file_path: pathlib.Path) -> dict:
    if not file_path.exists():
        return {}
    with open(file_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def save_yaml(file_path: pathlib.Path, data: dict):
    with open(file_path, "w", encoding="utf-8") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, indent=2)


def handle_team(action: str, name: str, slug: str, email: str, sync_groups: list, roles: list):
    file_path = VALUES_DIR / "Team.yaml"
    data = load_yaml(file_path)
    teams = data.get("teams", [])

    if action == "remove":
        data["teams"] = [t for t in teams if t.get("slug") != slug and t.get("name") != name]
        save_yaml(file_path, data)
        print(f"✅ Team '{slug or name}' removed successfully.")
        return

    # Add or update
    target = None
    for t in teams:
        if (slug and t.get("slug") == slug) or (name and t.get("name") == name):
            target = t
            break

    if target:
        if name: target["name"] = name
        if slug: target["slug"] = slug
        if email: target["email"] = email
        if sync_groups: target["syncGroups"] = sync_groups
        if roles: target["roles"] = roles
        print(f"✅ Team '{target['slug']}' updated successfully.")
    else:
        new_team = {
            "name": name,
            "slug": slug or name.lower().replace(" ", "-"),
        }
        if email:
            new_team["email"] = email
        if sync_groups:
            new_team["syncGroups"] = sync_groups
        if roles:
            new_team["roles"] = roles
        teams.append(new_team)
        data["teams"] = teams
        print(f"✅ Team '{new_team['slug']}' onboarded successfully.")

    save_yaml(file_path, data)


def handle_folder(action: str, title: str, uid: str, parent_uid: str, owner: str, admin_team: str):
    file_path = VALUES_DIR / "GrafanaFolder.yaml"
    data = load_yaml(file_path)
    folders = data.get("folders", [])

    if action == "remove":
        data["folders"] = [f for f in folders if f.get("uid") != uid and f.get("title") != title]
        save_yaml(file_path, data)
        print(f"✅ Folder '{uid or title}' removed successfully.")
        return

    # Add or update
    target = None
    for f in folders:
        if (uid and f.get("uid") == uid) or (title and f.get("title") == title):
            target = f
            break

    target_uid = uid or f"folder-{title.lower().replace(' ', '-')}"
    parent = parent_uid or "osttra"

    permissions = [
        {"role": "Viewer", "permission": 1}
    ]
    if admin_team:
        permissions.append({"team": admin_team, "permission": 4})

    if target:
        if title: target["title"] = title
        if uid: target["uid"] = uid
        target["parentUid"] = parent
        if owner: target["owner"] = owner
        if admin_team: target["permissions"] = permissions
        print(f"✅ Folder '{target['title']}' updated successfully.")
    else:
        new_folder = {
            "title": title,
            "uid": target_uid,
            "parentUid": parent,
            "owner": owner or admin_team or "platform",
            "permissions": permissions
        }
        folders.append(new_folder)
        data["folders"] = folders
        print(f"✅ Folder '{title}' onboarded successfully under '{parent}'.")

    save_yaml(file_path, data)


def handle_service_account(action: str, name: str, fixed_roles: list, owner: str):
    file_path = VALUES_DIR / "GrafanaServiceAccount.yaml"
    data = load_yaml(file_path)
    sas = data.get("serviceAccounts", [])

    if action == "remove":
        data["serviceAccounts"] = [sa for sa in sas if sa.get("name") != name]
        save_yaml(file_path, data)
        print(f"✅ Service Account '{name}' removed successfully.")
        return

    # Add or update
    target = None
    for sa in sas:
        if sa.get("name") == name:
            target = sa
            break

    secret_name = f"{name.lower().replace(' ', '-')}-token"

    if target:
        target["role"] = "None"
        if fixed_roles: target["fixedRoles"] = fixed_roles
        if owner: target["owner"] = owner
        print(f"✅ Service Account '{name}' updated successfully.")
    else:
        new_sa = {
            "name": name,
            "role": "None",
            "secretName": secret_name,
        }
        if owner:
            new_sa["owner"] = owner
        if fixed_roles:
            new_sa["fixedRoles"] = fixed_roles
        sas.append(new_sa)
        data["serviceAccounts"] = sas
        print(f"✅ Service Account '{name}' onboarded successfully.")

    save_yaml(file_path, data)


def handle_lbac(action: str, name: str, team: str, selector: str):
    file_path = VALUES_DIR / "TeamLBACRule.yaml"
    data = load_yaml(file_path)
    rules = data.get("lbacRules", [])

    if action == "remove":
        data["lbacRules"] = [r for r in rules if r.get("name") != name]
        save_yaml(file_path, data)
        print(f"✅ LBAC Rule '{name}' removed successfully.")
        return

    # Add or update
    target = None
    for r in rules:
        if r.get("name") == name:
            target = r
            break

    if target:
        if team: target["team"] = team
        if selector: target["selector"] = selector
        print(f"✅ LBAC Rule '{name}' updated successfully.")
    else:
        new_rule = {
            "name": name,
            "team": team or name,
            "datasource": "loki-lbac",
            "selector": selector
        }
        rules.append(new_rule)
        data["lbacRules"] = rules
        print(f"✅ LBAC Rule '{name}' onboarded successfully.")

    save_yaml(file_path, data)


def main():
    parser = argparse.ArgumentParser(description="Automated resource onboarding & management")
    parser.add_argument("--type", required=True, choices=["team", "folder", "service_account", "lbac_rule"], help="Resource type")
    parser.add_argument("--action", default="add_or_update", choices=["add_or_update", "remove"], help="Action to perform")
    parser.add_argument("--name", help="Name / Title of resource")
    parser.add_argument("--slug", help="Identifier / Slug / UID")
    parser.add_argument("--email", help="Contact email")
    parser.add_argument("--sync-groups", help="Comma-separated Azure AD group GUIDs")
    parser.add_argument("--roles", help="Comma-separated fixed roles (e.g. fixed:dashboards:reader)")
    parser.add_argument("--parent-uid", default="osttra", help="Parent folder UID (default: osttra)")
    parser.add_argument("--owner", help="Owner team identifier")
    parser.add_argument("--admin-team", help="Team granted Admin (permission: 4) on folder")
    parser.add_argument("--selector", help="Loki LogQL stream selector for LBAC")

    args = parser.parse_args()

    sync_groups = [g.strip() for g in args.sync_groups.split(",")] if args.sync_groups else []
    roles = [r.strip() for r in args.roles.split(",")] if args.roles else []

    if args.type == "team":
        if not args.name and not args.slug:
            sys.exit("Error: --name or --slug is required for team")
        handle_team(args.action, args.name or args.slug, args.slug or args.name.lower().replace(" ", "-"), args.email, sync_groups, roles)

    elif args.type == "folder":
        if not args.name and not args.slug:
            sys.exit("Error: --name (title) is required for folder")
        handle_folder(args.action, args.name or args.slug, args.slug, args.parent_uid, args.owner, args.admin_team)

    elif args.type == "service_account":
        if not args.name:
            sys.exit("Error: --name is required for service_account")
        handle_service_account(args.action, args.name, roles, args.owner)

    elif args.type == "lbac_rule":
        if not args.name:
            sys.exit("Error: --name is required for lbac_rule")
        handle_lbac(args.action, args.name, args.slug or args.name, args.selector or "")


if __name__ == "__main__":
    main()
