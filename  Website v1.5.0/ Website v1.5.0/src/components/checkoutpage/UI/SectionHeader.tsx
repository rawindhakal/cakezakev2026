import React from "react";

interface SectionHeaderProps {
  icon?: React.ReactNode;
  title: React.ReactNode;
  count?: React.ReactNode;
}

// Icon-led section header.
const SectionHeader = ({ icon, title, count }: SectionHeaderProps) => (
  <span className="font-bold text-lg md:text-xl flex items-center gap-2 min-w-0">
    {icon && (
      <span className="primaryColor dark:text-white shrink-0">{icon}</span>
    )}
    <span className="truncate">{title}</span>
    {count && (
      <span className="SecondaryTextColor font-normal text-sm md:text-base shrink-0">
        ({count})
      </span>
    )}
  </span>
);

export default SectionHeader;
