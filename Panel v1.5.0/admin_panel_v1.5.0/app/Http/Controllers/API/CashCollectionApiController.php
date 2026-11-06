<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\DeliveryBoy;
use App\Models\DeliveryBoyCashCollection;
use App\Models\DeliveryBoySettlement;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
class CashCollectionApiController extends Controller
{
    public function getCashCollection(Request $request){
    
        $countryId = (int) $request->input('country_id', 0);

        // Load delivery boys with all translations for language-wise display
        $deliveryBoys = DeliveryBoy::withAllTranslations()
            ->when($countryId, fn ($q) => $q->where('country_id', $countryId))
            ->orderBy('id', 'ASC')
            ->get(['id', 'name', 'mobile', 'country_code', 'cash_received', 'balance']);

        $transactions = DeliveryBoyCashCollection::select(
            'delivery_boy_cash_collections.id',
            'delivery_boy_cash_collections.delivery_boy_id',
            'delivery_boy_cash_collections.order_id',
            'delivery_boy_cash_collections.currency',
            'delivery_boy_cash_collections.type',
            'delivery_boy_cash_collections.amount',
            'delivery_boy_cash_collections.status',
            'delivery_boy_cash_collections.message',
            'delivery_boy_cash_collections.transaction_date',
            'orders.order_number',
            'orders.final_total',
            'orders.delivery_boy_bonus_amount',
            'delivery_boys.name',
            'delivery_boys.mobile',
            'delivery_boys.country_code',
            'delivery_boys.profile as delivery_boy_profile',
            'delivery_boys.admin_id as delivery_boy_admin_id'
        )
            ->leftJoin('orders', 'delivery_boy_cash_collections.order_id', '=', 'orders.id')
            ->leftJoin('delivery_boys', 'delivery_boy_cash_collections.delivery_boy_id', '=', 'delivery_boys.id')
            ->when($countryId, fn ($q) => $q->where('delivery_boys.country_id', $countryId))
            ->where('delivery_boy_cash_collections.type', DeliveryBoyCashCollection::$paymentTypeCod);

        if (isset($request->startDate) && $request->startDate != "" && isset($request->endDate) && $request->endDate != "") {
            $startDate = Carbon::parse($request->input('startDate'))->startOfDay();
            $endDate = Carbon::parse($request->input('endDate'))->endOfDay();

            $transactions->whereBetween('delivery_boy_cash_collections.created_at', [$startDate, $endDate]);
        }

        if (isset($request->delivery_boy_id) && $request->delivery_boy_id != "") {
            $transactions->where('delivery_boy_cash_collections.delivery_boy_id', $request->delivery_boy_id);
        }

        $transactions = $transactions->orderBy('delivery_boy_cash_collections.id', 'DESC')->get();
        
        // Load translations for delivery boys in transactions and attach them
        $deliveryBoyIds = $transactions->pluck('delivery_boy_id')->unique()->filter();
        if ($deliveryBoyIds->isNotEmpty()) {
            $deliveryBoysWithTranslations = DeliveryBoy::withAllTranslations()
                ->whereIn('id', $deliveryBoyIds)
                ->get()
                ->keyBy('id');
            
            // Attach translations to each transaction (convert to array for proper serialization)
            foreach ($transactions as $transaction) {
                if (isset($deliveryBoysWithTranslations[$transaction->delivery_boy_id])) {
                    $deliveryBoy = $deliveryBoysWithTranslations[$transaction->delivery_boy_id];
                    
                    // Get translations from the relationship (eager loaded via withAllTranslations)
                    // Check if relation is loaded first
                    if ($deliveryBoy->relationLoaded('translations')) {
                        $translations = $deliveryBoy->getRelation('translations');
                        // Convert collection to array if it's a collection
                        $transaction->translations = ($translations instanceof \Illuminate\Database\Eloquent\Collection) 
                            ? $translations->toArray() 
                            : (is_array($translations) ? $translations : []);
                    } else {
                        // If not loaded, load it and convert to array
                        $translations = $deliveryBoy->translations;
                        $transaction->translations = ($translations instanceof \Illuminate\Database\Eloquent\Collection) 
                            ? $translations->toArray() 
                            : (is_array($translations) ? $translations : []);
                    }
                }
            }
        }

        // Rider photo + email for the identity block beside the name.
        $contacts = CommonHelper::deliveryBoyContactMap($deliveryBoyIds->all());
        foreach ($transactions as $transaction) {
            $c = $contacts[$transaction->delivery_boy_id] ?? null;
            $transaction->profile_url = $c['profile_url'] ?? '';
            $transaction->email       = $c['email'] ?? '';
        }

        // Convert to array while preserving translations
        $transactionsArray = [];
        foreach($transactions as $transaction) {
            $row = $transaction->toArray();
            $row['message'] = CommonHelper::translateLedgerMessage($row['message'] ?? null);
            
            // Preserve translations if they exist (already converted to array in previous step)
            if (isset($transaction->translations)) {
                $row['translations'] = $transaction->translations;
            }
            
            $rawTransactionDate = $transaction->getAttributes()['transaction_date'] ?? null;
            if ($rawTransactionDate !== null && $rawTransactionDate !== '') {
                $row['transaction_date'] = $rawTransactionDate;
            }

            $transactionsArray[] = $row;
        }

        // Boys the admin still needs to collect cash from, with wallet balance so the
        // panel can offer wallet-mode settlement.
        $pendingCollections = DeliveryBoy::withAllTranslations()->with('country:id,currency')
            ->where('cash_received', '>', 0)
            ->when($countryId, fn ($q) => $q->where('country_id', $countryId))
            ->orderByDesc('cash_received')
            ->get(['id', 'name', 'mobile', 'country_code', 'cash_received', 'balance', 'country_id', 'profile', 'admin_id']);

        $pendingContacts = CommonHelper::deliveryBoyContactMap($pendingCollections->pluck('id')->all());
        $pendingCollections->each(function ($b) use ($pendingContacts) {
            $b->email = $pendingContacts[$b->id]['email'] ?? '';
        });

        $data = array(
            'deliveryBoys' => $deliveryBoys,
            'pendingCollections' => $pendingCollections,
            'transactions' => $transactionsArray
        );

        return CommonHelper::responseWithData($data);
    }

    public function save(Request $request){
        $validator = Validator::make($request->all(),[
            'deliveryBoy' => 'required|not_in:null',
            'amount' => 'required|numeric|min:0.01',
            'transaction_date' => 'required',
            'payment_mode' => 'nullable|in:cash,wallet',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $deliveryBoyData = json_decode($request->deliveryBoy);
        // Always settle against fresh DB values, never client-supplied balances.
        $deliveryBoy = DeliveryBoy::find($deliveryBoyData->id ?? 0);
        if (!$deliveryBoy) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }

        $amount = floatval($request->amount);
        $mode = $request->payment_mode ?: DeliveryBoyCashCollection::$modeCash;

        if ($amount > floatval($deliveryBoy->cash_received)) {
            return CommonHelper::responseError('amount_exceeds_cash_in_hand');
        }
        if ($mode == DeliveryBoyCashCollection::$modeWallet && $amount > floatval($deliveryBoy->balance)) {
            return CommonHelper::responseError('amount_exceeds_wallet_balance');
        }

        try {
            DB::beginTransaction();

            // Wallet mode debits the boy's wallet first; the cash row links that debit.
            $walletTransactionId = null;
            if ($mode == DeliveryBoyCashCollection::$modeWallet) {
                $walletTxn = CommonHelper::addDeliveryBoySettlement(
                    $deliveryBoy->id,
                    $amount,
                    DeliveryBoySettlement::$typeDebit,
                    'cash_collection_settled_against_wallet'
                );
                if (!$walletTxn) {
                    DB::rollBack();
                    return CommonHelper::responseError('something_went_wrong');
                }
                $walletTransactionId = $walletTxn->id;
            }

            $transaction = new DeliveryBoyCashCollection();
            $transaction->user_id = 0;
            $transaction->order_id = 0;
            $transaction->delivery_boy_id = $deliveryBoy->id;
            $transaction->type = DeliveryBoyCashCollection::$typeCashCollection;
            $transaction->payment_mode = $mode;
            $transaction->wallet_transaction_id = $walletTransactionId;
            $transaction->amount = $amount;
            $transaction->status = "success";
            // Message is always a translation key — translated per language on read.
            $transaction->message = $mode == DeliveryBoyCashCollection::$modeWallet
                ? 'cash_collection_adjusted_from_wallet'
                : 'cash_deposited_by_delivery_boy';
            $transaction->transaction_date = $request->transaction_date;
            $transaction->save();

            $deliveryBoy->refresh();
            $deliveryBoy->cash_received = round((float) $deliveryBoy->cash_received - (float) $amount, 2);
            $deliveryBoy->save();

            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('cash collection save error : ' . $e->getMessage());
            return CommonHelper::responseError('something_went_wrong');
        }

        return CommonHelper::responseSuccess('cash_collection_saved_successfully');
    }
}
