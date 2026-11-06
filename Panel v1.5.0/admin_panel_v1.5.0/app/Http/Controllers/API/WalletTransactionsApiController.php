<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Country;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class WalletTransactionsApiController extends Controller
{
    public function index(){

        $countryId = request('country_id') ?: null;
        $country   = $countryId ? Country::find($countryId) : null;

        $customers = User::orderBy('id','DESC')->get()->map(function (User $u) use ($countryId, $country) {
            $mobile = trim((string) ($u->mobile ?? ''));
            $code   = trim((string) ($u->country_code ?? ''));
            return [
                'id'           => $u->id,
                'name'         => $u->name,
                'mobile'       => $mobile,
                'country_code' => $code,
                'mobile_full'  => $mobile === '' ? '' : trim($code . ' ' . $mobile),
                'email'        => $u->email,
                'balance'      => CommonHelper::getUserWalletBalance($u->id, $countryId),
                'currency'     => $country->currency ?? null,
            ];
        })->values();

        $walletTransactions = WalletTransaction::select('users.name', 'wallet_transactions.*')
            ->leftJoin('users', 'wallet_transactions.user_id', '=', 'users.id')
            ->when($countryId, fn ($q) => $q->where(function ($w) use ($countryId) {
                $w->where('wallet_transactions.country_id', $countryId)
                    ->orWhereNull('wallet_transactions.country_id');
            }))
            ->when(request('zone_id'), fn ($q) => $q->where('wallet_transactions.zone_id', request('zone_id')))
            ->orderBy('wallet_transactions.id','DESC')->get();
        foreach ($walletTransactions as $wt) {
            $wt->message = CommonHelper::translateTransactionMessage($wt->message);
        }
        $walletTransactions = $walletTransactions->map(function (WalletTransaction $wt) {
            $row = $wt->toArray();
            $rawUpdatedAt = $wt->getAttributes()['updated_at'] ?? null;
            $rawTransactionDate = $wt->getAttributes()['transaction_date'] ?? null;
            if ($rawUpdatedAt !== null && $rawUpdatedAt !== '') {
                $row['updated_at'] = $rawUpdatedAt;
                $row['transaction_date'] = $rawTransactionDate;
            }
            return $row;
        });
        $data = array(
            'customers' => $customers,
            'walletTransactions' => $walletTransactions,
            'country_id' => $countryId,
            'currency' => $country->currency ?? null,
            'currency_code' => $country->currency_code ?? null,
        );
        return CommonHelper::responseWithData($data);
    }

    public function save(Request $request){
        $validator = Validator::make($request->all(),[
            'customer' => 'required',
            'amount' => 'required|numeric|min:0.01',
            'country_id' => 'required|exists:countries,id',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $customerData = json_decode($request->customer);
        $customer = User::find($customerData->id ?? 0);
        if (!$customer) {
            return CommonHelper::responseError('customer_not_found');
        }

        $amount = round((float) $request->amount, 2);
        $countryId = (int) $request->country_id;
        $country = Country::find($countryId);

        $walletTransactions = new WalletTransaction();
        $walletTransactions->user_id = $customer->id;
        $walletTransactions->type = 'credit';
        $walletTransactions->amount	 = $amount;
        $walletTransactions->txn_id	 = 'admin';
        $walletTransactions->payment_type = 'admin';
        $walletTransactions->message = $request->message;
        $walletTransactions->status = 1;
        $walletTransactions->country_id = $countryId;

        $creator = auth()->user();
        $walletTransactions->zone_id = ($creator && $creator->isBranchUser())
            ? optional($creator->branch)->zone_id
            : null;
        $walletTransactions->currency = $country->currency ?? null;
        $walletTransactions->currency_code = $country->currency_code ?? null;
        $walletTransactions->save();

        // `$customer->balance` is only a virtual accessor over user_wallets — assigning to
        // it moves no money. The balance must be written through the wallet helper.
        CommonHelper::addUserWalletBalance($amount, $customer->id, $countryId);

        CommonHelper::sendWalletNotification(
            $customer,
            $amount,
            'wallet_admin_credit_customer',
            'customer_wallet_admin_credit',
            ['message' => $request->message ?? ''],
            $countryId,
            $walletTransactions->id
        );

        return CommonHelper::responseSuccess('wallet_transaction_saved_successfully');
    }
}
