<?php

namespace App\Http\Controllers;

use App\Helpers\CommonHelper;
use App\Helpers\PermissionsChecker;
use App\Helpers\RequirementsChecker;
use App\Http\Controllers\API\GeneralSettingsApiController;
use App\Models\Admin;
use Brotzka\DotenvEditor\DotenvEditor;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Validator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
class InstallController
{
    protected $requirements;
    protected $permissions;
    public function __construct(RequirementsChecker $requirements, PermissionsChecker $permissions)
    {
        $this->requirements = $requirements;
        $this->permissions = $permissions;
    }

    public function getRequirements(){

        $phpSupportInfo = $this->requirements->checkPHPversion(
            config('installer.core.minPhpVersion')
        );

        $requirements = $this->requirements->check(
            config('installer.requirements')
        );

        $permissions = $this->permissions->check(
            config('installer.permissions')
        );

        $data = array();
        $data['phpSupportInfo'] = $phpSupportInfo;
        $data['requirements'] = $requirements;
        $data['permissions'] = $permissions;

        return CommonHelper::responseWithData($data);
    }

    /*Database*/
    public function checkDatabaseConnection($database_host, $database_port, $database_name, $database_username, $database_password){

        $connection  = 'mysql';

        config([
            'database.default' => $connection,
            "database.connections.$connection.driver"   => $connection,
            "database.connections.$connection.host"     => $database_host,
            "database.connections.$connection.port"     => $database_port,
            "database.connections.$connection.database" => $database_name,
            "database.connections.$connection.username" => $database_username,
            "database.connections.$connection.password" => $database_password,
        ]);

        DB::purge($connection);

        try {

            DB::connection()->getPdo();

            return true;

        } catch (\Exception $e) {

            return false;
        }
    }

    public function setDatabase(Request $request){

        $validator = Validator::make($request->all(),[
            'database_host'     => 'required',
            'database_port'     => 'required',
            'database_name'     => 'required',
            'admin_email'       => 'required|email',
            'admin_password'    => 'required|min:6'
        ]);
        if ($validator->fails   ()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        try {

            $database_host = $request->database_host;
            $database_port = $request->database_port;
            $database_name = $request->database_name;
            $database_username = $request->database_username;
            $database_password = $request->database_password;

            $admin_email = $request->admin_email;
            $admin_password = $request->admin_password;

            if (! $this->checkDatabaseConnection($database_host, $database_port, $database_name, $database_username, $database_password) ) {
                return CommonHelper::responseError("Could not connect to the database. Maybe your Database is not available.");
            }

            try {

                $env = new DotenvEditor();

                $envValues = [
                    'DB_HOST'     => $database_host,
                    'DB_PORT'     => $database_port,
                    'DB_DATABASE' => $database_name,
                    'DB_USERNAME' => $database_username,
                    'DB_PASSWORD' => $database_password,
                    'APP_URL'     => url('/'),
                    'APP_ENV'     => 'production',
                ];

                $envValues += $this->generateReverbCredentials();

                if (env('INSTALL_MODE') === 'server') {
                    if (class_exists(\Barryvdh\Debugbar\Facades\Debugbar::class)) {
                        \Barryvdh\Debugbar\Facades\Debugbar::disable();
                    }
                    @ini_set('memory_limit', '-1');
                    @set_time_limit(0);
                    ignore_user_abort(true);

                    config([
                        'database.connections.mysql.host' => $database_host,
                        'database.connections.mysql.port' => $database_port,
                        'database.connections.mysql.database' => $database_name,
                        'database.connections.mysql.username' => $database_username,
                        'database.connections.mysql.password' => $database_password,
                    ]);
                    DB::purge('mysql');
                    DB::reconnect('mysql');

                    Artisan::call('config:clear');
                    Artisan::call('migrate:fresh', ['--force' => true]);
                    Artisan::call('db:seed', ['--force' => true]);
                    Artisan::call('migrate', ['--path' => 'vendor/laravel/passport/database/migrations', '--force' => true]);
                    Artisan::call('passport:install', ['--no-interaction' => true]);
                    Artisan::call('storage:link', ['--force' => true]);
                }

                $installedLogFile = storage_path('installed');
                $dateStamp = date('Y/m/d h:i:sa');
                if (! file_exists($installedLogFile)) {
                    $message = "CakeZake Installer successfully Installed on ".$dateStamp."\n";
                    file_put_contents($installedLogFile, $message);
                } else {
                    $message = "CakeZake Installer successfully UPDATED on ".$dateStamp;
                    file_put_contents($installedLogFile, $message.PHP_EOL, FILE_APPEND | LOCK_EX);
                }

                Admin::truncate();
                $superAdmin = Admin::create([
                    'username' => 'superadmin',
                    'email' => $admin_email,
                    'password' => bcrypt($admin_password),
                    'role_id' => 1,
                    'created_by' => 1,
                ]);
                $superAdmin->assignRole('Super Admin');

                $env->changeEnv($envValues);

                return CommonHelper::responseSuccess("Database");

            } catch (\Exception $e) {
                return CommonHelper::responseError($e->getMessage());
            }

        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }

    private function generateReverbCredentials(): array
    {
        $generated = [];

        if (empty(env('REVERB_APP_ID'))) {
            $generated['REVERB_APP_ID'] = (string) random_int(100000, 999999);
        }
        if (empty(env('REVERB_APP_KEY'))) {
            $generated['REVERB_APP_KEY'] = Str::lower(Str::random(20));
        }
        if (empty(env('REVERB_APP_SECRET'))) {
            $generated['REVERB_APP_SECRET'] = Str::lower(Str::random(20));
        }

        return $generated;
    }

    public function checkPurchaseCode(Request $request){

        $validator = Validator::make($request->all(),[
            'purchase_code'     => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        try {

            $response = app(GeneralSettingsApiController::class)->verifyPurchaseCode((string) $request->purchase_code);
            if($response){

                return CommonHelper::responseSuccess("Valid");
            }else{
                return CommonHelper::responseError("Invalid code supplied!");
            }
        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage());
        }
    }
}
