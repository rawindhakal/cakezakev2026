<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Transaction;

class TransactionsApiController extends Controller
{
    public function index(){
        $transactions = Transaction::select('users.name', 'transactions.*', 'orders.order_number')
            ->leftJoin('users', 'transactions.user_id', '=', 'users.id')
            ->leftJoin('orders', 'transactions.order_id', '=', 'orders.id')
            ->orderBy('transactions.id','DESC')->get();
        foreach ($transactions as $t) {
            $t->message = CommonHelper::translateTransactionMessage($t->message);
            $t->type = CommonHelper::translateTransactionMessage($t->type);
        }

        $transactionsForResponse = $transactions->map(function (Transaction $t) {
            $row = $t->toArray();
            $rawCreated = $t->getAttributes()['transaction_date'] ?? null;
            if ($rawCreated !== null && $rawCreated !== '') {
                $row['transaction_date'] = $rawCreated;
            }
            return $row;
        });

        return CommonHelper::responseWithData($transactionsForResponse);
    }
}
