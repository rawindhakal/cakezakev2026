<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.3.1.
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->addBulkPlaceholdersToItemTemplates();
        $this->markProvenIdentitiesVerified();
        $this->syncPermissions();
    }

    public function down(): void
    {
        $this->removeTemplatePlaceholders('order_item_status_customer', ['items_count', 'product_names']);
        $this->removeTemplatePlaceholders('order_item_cancelled_customer', ['items_count', 'product_names']);
        $this->dropPermissions(['manage_invoice_settings']);
    }

    /**
     * `users.is_verified` was only ever written by the email flow, so every phone and
     * social customer sits at 0 although their identity was proven at sign-up (OTP /
     * provider). Registration now treats an unverified row as an abandoned attempt that
     * may be re-registered, so those existing accounts have to be flagged verified or a
     * stranger could re-register the number and overwrite the password.
     */
    private function markProvenIdentitiesVerified(): void
    {
        if (!Schema::hasTable('users') || !Schema::hasColumn('users', 'is_verified')) {
            return;
        }

        DB::table('users')
            ->whereIn('type', ['phone', 'google', 'apple'])
            ->where('is_verified', 0)
            ->update(['is_verified' => 1]);
    }

    /**
     * Invoice & delivery-receipt print settings get their own permission, mirrored onto
     * whoever already manages general settings. A fresh install is left to the seeder.
     */
    private function syncPermissions(): void
    {
        if (!Schema::hasTable('permissions') || !Schema::hasTable('permission_categories') || !Schema::hasTable('roles')) {
            return;
        }
        if (!DB::table('permission_categories')->exists()) {
            return; // fresh install — the seeder owns this
        }

        // permission => the existing permission whose holders it follows
        $mirrored = ['manage_invoice_settings' => 'manage_general_settings'];

        $categoryId = DB::table('permission_categories')->where('name', 'settings')->value('id')
            ?: DB::table('permission_categories')->insertGetId(['name' => 'settings', 'guard_name' => 'web']);

        foreach ($mirrored as $name => $mirror) {
            $id = DB::table('permissions')->where('name', $name)->value('id');
            if (!$id) {
                $id = DB::table('permissions')->insertGetId([
                    'name'        => $name,
                    'guard_name'  => 'web',
                    'category_id' => $categoryId,
                    'created_at'  => now(),
                    'updated_at'  => now(),
                ]);
            }

            $sourceId = DB::table('permissions')->where('name', $mirror)->value('id');
            $roleIds = $sourceId
                ? DB::table('role_has_permissions')->where('permission_id', $sourceId)->pluck('role_id')
                : DB::table('roles')->whereIn('name', ['Super Admin', 'Admin'])->pluck('id');

            foreach ($roleIds as $rid) {
                DB::table('role_has_permissions')->updateOrInsert(
                    ['permission_id' => $id, 'role_id' => $rid],
                    ['permission_id' => $id, 'role_id' => $rid]
                );
            }
        }
    }

    private function dropPermissions(array $names): void
    {
        if (!Schema::hasTable('permissions')) {
            return;
        }
        $ids = DB::table('permissions')->whereIn('name', $names)->pluck('id');
        if ($ids->isEmpty()) {
            return;
        }
        foreach (['role_has_permissions', 'model_has_permissions'] as $pivot) {
            if (Schema::hasTable($pivot)) {
                DB::table($pivot)->whereIn('permission_id', $ids)->delete();
            }
        }
        DB::table('permissions')->whereIn('id', $ids)->delete();
    }

    /**
     * Admin can now update / cancel several order items in one action, and that fires a
     * single customer message for the whole group ("Blue Shirt +2 more"). The template
     * may therefore say how many items moved and name them all. The panel lists a
     * template's own placeholders, so the stored rows are extended, not just the code.
     */
    private function addBulkPlaceholdersToItemTemplates(): void
    {
        $this->appendTemplatePlaceholders('order_item_status_customer', ['items_count', 'product_names']);
        $this->appendTemplatePlaceholders('order_item_cancelled_customer', ['items_count', 'product_names']);
    }

    /** Append placeholder keys to every stored template whose type matches (idempotent). */
    private function appendTemplatePlaceholders(string $type, array $keys): void
    {
        $this->eachTemplate($type, function (array $list) use ($keys) {
            foreach ($keys as $key) {
                if (!in_array($key, $list, true)) {
                    $list[] = $key;
                }
            }

            return $list;
        });
    }

    /** Reverse of the above — leaves any other placeholder untouched. */
    private function removeTemplatePlaceholders(string $type, array $keys): void
    {
        $this->eachTemplate($type, fn (array $list) => array_values(array_diff($list, $keys)));
    }

    /** Rewrite the placeholders list of matching rows in all three template tables. */
    private function eachTemplate(string $type, callable $rewrite): void
    {
        foreach (['notification_templates', 'email_templates', 'sms_templates'] as $table) {
            if (!Schema::hasTable($table) || !Schema::hasColumn($table, 'placeholders')) {
                continue;
            }
            $rows = DB::table($table)->select('id', 'placeholders')->where('type', 'like', $type)->get();
            foreach ($rows as $row) {
                $list = json_decode($row->placeholders ?? '[]', true);
                if (!is_array($list)) {
                    $list = [];
                }
                $next = array_values($rewrite($list));
                if ($next !== $list) {
                    DB::table($table)->where('id', $row->id)->update(['placeholders' => json_encode($next)]);
                }
            }
        }
    }
};
