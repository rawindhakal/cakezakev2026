// Permission dependency: a "*_list" permission is the prerequisite for its
// create/update/delete siblings. If list is turned OFF, the siblings turn off
// (you can't act on a module you can't view); turning a sibling ON implies list.
//
// Groups are keyed by the base name (permission minus its trailing action word),
// e.g. category_list / category_create / category_update / category_delete share
// the base "category". Groups without a "<base>_list" permission are left alone.

const ACTION_SUFFIXES = ['_list', '_create', '_update', '_delete'];

function baseOf(name) {
    for (const suffix of ACTION_SUFFIXES) {
        if (name.endsWith(suffix)) {
            return name.slice(0, -suffix.length);
        }
    }
    return null; // not a list/create/update/delete permission
}

/**
 * Return the adjusted selected-id array after toggling `toggled` ({id, name}).
 * @param {Array<number>} selectedIds  currently checked permission ids (post-toggle)
 * @param {Array<{permissions:Array<{id:number,name:string}>}>} categories
 * @param {{id:number,name:string}} toggled  the permission whose checkbox changed
 */
export function cascadePermission(selectedIds, categories, toggled) {
    const base = baseOf(toggled.name);
    if (!base) return selectedIds.slice();

    const all = [];
    (categories || []).forEach(c => (c.permissions || []).forEach(p => all.push(p)));

    const listPerm = all.find(p => p.name === base + '_list');
    if (!listPerm) return selectedIds.slice(); // group has no list permission

    const set = new Set(selectedIds);
    const isList = toggled.name === base + '_list';
    const nowOn = set.has(toggled.id);

    if (isList && !nowOn) {
        // List turned OFF -> drop every sibling in this base group.
        all.forEach(p => { if (baseOf(p.name) === base) set.delete(p.id); });
    } else if (!isList && nowOn) {
        // A sibling turned ON -> list is required, so switch it on.
        set.add(listPerm.id);
    }
    return Array.from(set);
}
