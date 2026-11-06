import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { RESERVED_ROUTES } from "@/utils/reservedRoutes";
import { getEdgeLanguages } from "@/utils/languageEdge";

// Edge proxy middleware handling language canonicalization and legacy route redirects.
export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const segments = pathname.split("/").filter(Boolean);

  const { codes, defaultCode } = await getEdgeLanguages();

  const first = segments[0];
  const hasExplicitLang = !!first && codes.has(first);

  // Redirect explicit default language prefix to canonical URL.
  if (hasExplicitLang && first === defaultCode) {
    const target = request.nextUrl.clone();
    target.pathname = segments.length > 1 ? `/${segments.slice(1).join("/")}` : "/";
    return NextResponse.redirect(target, 308);
  }

  // Rest of path segments after optional language prefix.
  const rest = hasExplicitLang ? segments.slice(1) : segments;

  // Redirect legacy zoned blog links to canonical non-zoned blog path.
  if (
    rest.length >= 2 &&
    (rest[1] === "blog" || rest[1] === "blogs") &&
    rest[0] &&
    !RESERVED_ROUTES.has(rest[0])
  ) {
    const target = request.nextUrl.clone();
    const langPrefix = hasExplicitLang ? `/${first}` : "";
    target.pathname = `${langPrefix}/${rest.slice(1).join("/")}`;
    return NextResponse.redirect(target, 308);
  }

  // Proceed for valid non-default language prefixes.
  if (hasExplicitLang) return NextResponse.next();

  // Rewrite request internally to prepend default language code.
  const url = request.nextUrl.clone();
  url.pathname = `/${defaultCode}${pathname === "/" ? "" : pathname}`;
  return NextResponse.rewrite(url);
}

export const config = {
  // Matcher excluding static assets and Next.js internal routes.
  matcher: ["/((?!_next/static|_next/image|_next/data|favicon.ico|.*\\..*).*)"],
};

