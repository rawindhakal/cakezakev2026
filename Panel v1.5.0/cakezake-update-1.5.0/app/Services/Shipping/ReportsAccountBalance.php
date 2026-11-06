<?php

namespace App\Services\Shipping;

/**
 * A carrier that charges from a prepaid account the client tops up themselves.
 *
 * Shiprocket is one: it pays the couriers out of a wallet, and when that wallet empties
 * waybill assignment starts failing with a message that never mentions money. The panel
 * therefore shows the balance beside the shipping actions rather than waiting for a
 * booking to fail — a number on screen is cheaper than a support ticket.
 *
 * Optional, because a carrier billed monthly on invoice has no balance to report.
 */
interface ReportsAccountBalance
{
    /**
     * @return array{ok:bool, balance:?float, currency:?string, message:?string}
     */
    public function accountBalance(): array;
}
