import * as React from "react"
import * as DialogPrimitive from "@radix-ui/react-dialog"
import { X } from "lucide-react"

import { cn } from "@/lib/utils"

const Dialog = DialogPrimitive.Root

const DialogTrigger = DialogPrimitive.Trigger

const DialogPortal = DialogPrimitive.Portal

const DialogClose = DialogPrimitive.Close

const DialogOverlay = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Overlay>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Overlay>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Overlay
    ref={ref}
    className={cn(
      "fixed inset-0 z-50 bg-black/40  data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
      className
    )}
    {...props} />
))
DialogOverlay.displayName = DialogPrimitive.Overlay.displayName

// Accessible DialogContent props with optional title, description, and overlay style.
export interface DialogContentProps
  extends Omit<
    React.ComponentPropsWithoutRef<typeof DialogPrimitive.Content>,
    "title"
  > {
  title?: React.ReactNode;
  description?: React.ReactNode;
  /** Custom overlay class names. */
  overlayClassName?: string;
  /** Below `sm`, dock to the bottom edge and slide up like a sheet. */
  sheetOnMobile?: boolean;
}

// Shared chrome for both layouts.
const CONTENT_BASE =
  "fixed z-[51] grid w-full gap-4 border bg-background p-2 md:p-6 shadow-lg duration-200 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0";

// Centred dialog: the default.
const CONTENT_CENTERED =
  "left-[50%] top-[50%] max-w-lg translate-x-[-50%] translate-y-[-50%] data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%] data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%] sm:rounded-lg";

// Mobile sheet: bottom-docked, full width, rounded top, slides up. The slide
// classes are written out per breakpoint rather than overridden — tailwind-merge
// does not know the animate plugin's groups, so an override would not win
// reliably. From `md` up this matches CONTENT_CENTERED exactly; `md` is the
// app's phone cutoff (the bottom nav uses it) and a 1080px/1.5dpr phone already
// reports ~720px, which is past `sm`.
const CONTENT_SHEET_ON_MOBILE =
  "inset-x-0 bottom-0 top-auto max-h-[92dvh] rounded-t-2xl " +
  "data-[state=open]:slide-in-from-bottom data-[state=closed]:slide-out-to-bottom " +
  "md:inset-x-auto md:bottom-auto md:left-[50%] md:top-[50%] md:max-w-lg md:translate-x-[-50%] md:translate-y-[-50%] md:rounded-lg " +
  "md:data-[state=closed]:zoom-out-95 md:data-[state=open]:zoom-in-95 " +
  "md:data-[state=closed]:slide-out-to-left-1/2 md:data-[state=closed]:slide-out-to-top-[48%] " +
  "md:data-[state=open]:slide-in-from-left-1/2 md:data-[state=open]:slide-in-from-top-[48%]";

const DialogContent = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Content>,
  DialogContentProps
>((
  {
    className,
    children,
    title,
    description,
    overlayClassName,
    sheetOnMobile,
    ...props
  },
  ref,
) => (
  <DialogPortal>
    <DialogOverlay className={overlayClassName} />
    <DialogPrimitive.Content
      ref={ref}
      className={cn(
        CONTENT_BASE,
        sheetOnMobile ? CONTENT_SHEET_ON_MOBILE : CONTENT_CENTERED,
        className
      )}
      {...props}>
      {title ? (
        <DialogPrimitive.Title className="sr-only">{title}</DialogPrimitive.Title>
      ) : null}
      {description ? (
        <DialogPrimitive.Description className="sr-only">
          {description}
        </DialogPrimitive.Description>
      ) : null}
      {children}
    </DialogPrimitive.Content>
  </DialogPortal>
))
DialogContent.displayName = DialogPrimitive.Content.displayName

const DialogHeader = ({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) => (
  <div
    className={cn("flex flex-col space-y-1.5 text-center sm:text-left", className)}
    {...props} />
)
DialogHeader.displayName = "DialogHeader"

const DialogFooter = ({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) => (
  <div
    className={cn("flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2", className)}
    {...props} />
)
DialogFooter.displayName = "DialogFooter"

const DialogTitle = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Title>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Title>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Title
    ref={ref}
    className={cn("text-lg font-semibold leading-none tracking-tight", className)}
    {...props} />
))
DialogTitle.displayName = DialogPrimitive.Title.displayName

const DialogDescription = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Description>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Description>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Description
    ref={ref}
    className={cn("text-sm text-muted-foreground", className)}
    {...props} />
))
DialogDescription.displayName = DialogPrimitive.Description.displayName

export {
  Dialog,
  DialogPortal,
  DialogOverlay,
  DialogTrigger,
  DialogClose,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
}
