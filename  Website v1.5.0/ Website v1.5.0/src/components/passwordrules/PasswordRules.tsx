"use client";
import { FiCheck, FiX } from "react-icons/fi";
import { usePasswordRules } from "@/utils/passwordValidation";

/** Live checklist for password rules. */
interface PasswordRulesProps {
  password?: string;
  className?: string;
}

const PasswordRules = ({ password = "", className = "" }: PasswordRulesProps) => {
  // Unconditionally evaluate password rules hook
  const rules = usePasswordRules(password);
  if (!password || !rules.length) return null;

  return (
    <ul className={`mt-1.5 flex flex-col gap-1 ${className}`}>
      {rules.map((rule) => (
        <li
          key={rule.key}
          className={`flex items-center gap-1.5 text-xs ${
            rule.passed ? "text-green-600" : "text-gray-500 dark:text-zinc-400"
          }`}
        >
          {rule.passed ? (
            <FiCheck size={13} className="shrink-0" />
          ) : (
            <FiX size={13} className="shrink-0 text-gray-400" />
          )}
          <span>{rule.label}</span>
        </li>
      ))}
    </ul>
  );
};

export default PasswordRules;
