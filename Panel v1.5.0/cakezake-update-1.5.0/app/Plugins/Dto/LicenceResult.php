<?php

namespace App\Plugins\Dto;

/**
 * The outcome of a licence check.
 *
 * `reachable` is the field that matters: false means we could not get an answer, which
 * is treated very differently from an answer of "no".
 */
final class LicenceResult
{
    private function __construct(
        public readonly bool $ok,
        public readonly bool $reachable,
        public readonly string $reason,
        public readonly ?string $message = null,
        /**
         * Which validator line answered.
         *
         * Not readonly, and not a constructor argument: a plugin may be sold on the
         * universal line or a product's own, so the caller tries them in turn and
         * records which one replied. The row stores it so a later re-check asks the
         * same place instead of walking the list again.
         */
        public ?string $url = null,
    ) {}

    public static function valid(?string $message = null): self
    {
        return new self(true, true, 'valid', $message);
    }

    public static function rejected(string $message): self
    {
        return new self(false, true, 'rejected', $message);
    }

    public static function unreachable(?string $message = null): self
    {
        return new self(false, false, 'unreachable', $message);
    }
}
