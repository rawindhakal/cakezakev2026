<?php

namespace App\Services\Shipping;

/**
 * A carrier that can be told not to pick the courier itself.
 *
 * Most carriers hand back a waybill the moment a parcel is booked, and the panel is
 * built around that: a tracking number, a label, a pickup. Some let the shop allocate
 * couriers in the carrier's own console instead — Shiprocket's "assign waybill
 * automatically" switch is exactly that — and then a booking deliberately comes back
 * without one.
 *
 * Implement this only to answer false some of the time. A provider that does not
 * implement it is assumed to assign on booking, which is what every caller expected
 * before this interface existed.
 */
interface AssignsWaybillOnBooking
{
    /**
     * Will createShipment() come back with a waybill?
     *
     * False means the shop allocates the courier in the carrier's console, so nothing
     * unattended — a cron, a sweep — may assign one on its behalf. Something the admin
     * asked for directly, like printing a label, still may: a label cannot exist
     * without a waybill.
     */
    public function assignsWaybillOnBooking(): bool;
}
