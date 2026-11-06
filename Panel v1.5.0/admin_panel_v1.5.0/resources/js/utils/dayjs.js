import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import relativeTime from 'dayjs/plugin/relativeTime';
import customParseFormat from 'dayjs/plugin/customParseFormat';
import localizedFormat from 'dayjs/plugin/localizedFormat';
import advancedFormat from 'dayjs/plugin/advancedFormat';
import duration from 'dayjs/plugin/duration';
import weekday from 'dayjs/plugin/weekday';
import isBetween from 'dayjs/plugin/isBetween';

dayjs.extend(utc);
dayjs.extend(relativeTime);
dayjs.extend(customParseFormat);
dayjs.extend(localizedFormat);
dayjs.extend(advancedFormat);
dayjs.extend(duration);
dayjs.extend(weekday);
dayjs.extend(isBetween);

export default dayjs;
