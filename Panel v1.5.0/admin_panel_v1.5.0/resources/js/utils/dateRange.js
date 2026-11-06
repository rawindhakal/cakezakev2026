import dayjs from './dayjs';
export const DATE_RANGE_FORMAT = 'DD-MM-YYYY';
export const DATE_RANGE_SEPARATOR = ' to ';

export function buildDateRangeConfig(overrides = {}) {
    return {
        dateFormat: 'd-m-Y',
        mode: 'range',
        ...overrides
    };
}

function getRangeParts(range) {
    if (!range || typeof range !== 'string') {
        return [];
    }

    return range.split(DATE_RANGE_SEPARATOR).map((part) => part.trim()).filter(Boolean);
}

function parseRangeDate(value) {
    if (!value) {
        return null;
    }

    const parsed = dayjs(value, DATE_RANGE_FORMAT, true);
    return parsed.isValid() ? parsed : null;
}

export function getRangeStart(range) {
    const [start] = getRangeParts(range);
    return parseRangeDate(start);
}

export function getRangeEnd(range) {
    const [, end] = getRangeParts(range);
    return parseRangeDate(end);
}

export function toApiDate(range, boundary) {
    const momentValue = boundary === 'end' ? getRangeEnd(range) : getRangeStart(range);
    return momentValue ? momentValue.format('YYYY-MM-DD') : '';
}

export function getLastNDaysRange(days = 30) {
    const endDate = dayjs();
    const startDate = dayjs().subtract(days, 'days');
    return `${startDate.format(DATE_RANGE_FORMAT)}${DATE_RANGE_SEPARATOR}${endDate.format(DATE_RANGE_FORMAT)}`;
}
