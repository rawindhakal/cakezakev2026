<?php

namespace App\Exports;

use Maatwebsite\Excel\Concerns\FromArray;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithStyles;
use Maatwebsite\Excel\Concerns\WithTitle;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;

/**
 * Generic report -> xlsx. Rows/headings are already flattened by ReportsApiController,
 * so this stays report-agnostic.
 */
class ReportExport implements FromArray, WithHeadings, WithStyles, WithTitle, ShouldAutoSize
{
    public function __construct(
        private array $rows,
        private array $headings,
        private string $title,
        /** Admin theme colour (#rrggbb) so the sheet matches the panel's branding. */
        private string $themeColor = '#435ebe',
    ) {}

    public function array(): array
    {
        return $this->rows;
    }

    public function headings(): array
    {
        return $this->headings;
    }

    public function title(): string
    {
        // Excel sheet names cap at 31 chars and reject a few characters.
        return substr(preg_replace('/[\\\\\/\*\?\:\[\]]/', '', $this->title), 0, 31) ?: 'Report';
    }

    public function styles(Worksheet $sheet): array
    {
        // PhpSpreadsheet wants a bare RRGGBB, not a CSS #rrggbb.
        $rgb = strtoupper(ltrim($this->themeColor, '#'));
        if (!preg_match('/^[0-9A-F]{6}$/', $rgb)) {
            $rgb = '435EBE';
        }

        return [
            1 => [
                'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
                'fill' => ['fillType' => 'solid', 'startColor' => ['rgb' => $rgb]],
            ],
        ];
    }
}
