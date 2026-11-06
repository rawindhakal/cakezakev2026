<?php

namespace Database\Seeders;

use App\Models\Language;
use App\Models\SupportedLanguage;
use App\Services\LanguageFileService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\File;

class LanguageSeeder extends Seeder
{
   
    public function run()
    {
        $supportedLanguageId = 16;

        $displayName = 'English';

        $slug = Language::slugForSupportedLanguage($supportedLanguageId);
        
        $systemTypeFiles = [
            Language::SYSTEM_TYPE_CUSTOMER_APP     => 'customer.json',
            Language::SYSTEM_TYPE_DELIVERY_BOY_APP => 'partner.json',
            Language::SYSTEM_TYPE_WEBSITE          => 'web.json',
            Language::SYSTEM_TYPE_ADMIN_PANEL      => 'panel.json',
        ];

        $code = SupportedLanguage::where('id', $supportedLanguageId)->value('code');

        Language::where('is_default', 1)->update(['is_default' => 0]);
        
        foreach ($systemTypeFiles as $systemType => $fileName) {
            $filePath = public_path('sample-file/' . $fileName);
            
            if (!File::exists($filePath)) {
                $this->command->warn("Sample file not found: {$fileName}. Skipping system type {$systemType}.");
                continue;
            }
            
            $jsonContent = File::get($filePath);
            
            $jsonData = json_decode($jsonContent, true);
            if (json_last_error() !== JSON_ERROR_NONE) {
                $this->command->error("Invalid JSON in file: {$fileName}. Error: " . json_last_error_msg());
                continue;
            }
            
            $jsonString = json_encode($jsonData);

            if ($code && !LanguageFileService::exists($systemType, $code)) {
                try {
                    LanguageFileService::write($systemType, $code, $jsonString);
                } catch (\Throwable $e) {
                    $this->command->error("Could not write language file for system type {$systemType}: " . $e->getMessage());
                }
            }

            $existingLanguage = Language::where('supported_language_id', $supportedLanguageId)
                ->where('system_type', $systemType)
                ->first();
            
            if ($existingLanguage) {
                $existingLanguage->update([
                    'display_name' => $displayName,
                    'slug' => $slug,
                    'is_default' => 1,
                    'status' => 1
                ]);
                
                $this->command->info("Updated English language for system type {$systemType} ({$fileName})");
            } else {
                Language::create([
                    'supported_language_id' => $supportedLanguageId,
                    'system_type' => $systemType,
                    'display_name' => $displayName,
                    'slug' => $slug,
                    'is_default' => 1,
                    'status' => 1
                ]);
                
                $this->command->info("Created English language for system type {$systemType} ({$fileName})");
            }
        }
        
        Language::where('supported_language_id', '!=', $supportedLanguageId)
            ->where('is_default', 1)
            ->update(['is_default' => 0]);
        
        $this->command->info("English language seeder completed successfully!");
    }
}

