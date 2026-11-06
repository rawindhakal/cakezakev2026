"use client"

import * as React from "react"
import * as TooltipPrimitive from "@radix-ui/react-tooltip"

import { cn } from "@/lib/utils"

const TooltipProvider = TooltipPrimitive.Provider

// Radix opens tooltips on hover/focus only, so every (i) was dead on touch.
// The root tracks open state itself and the trigger toggles it on a non-mouse
// tap; mouse users keep plain hover behaviour.
interface TooltipCtx {
  open: boolean
  setOpen: (next: boolean | ((prev: boolean) => boolean)) => void
}

const TooltipOpenContext = React.createContext<TooltipCtx | null>(null)

const Tooltip = ({
  open,
  defaultOpen,
  onOpenChange,
  children,
  ...props
}: React.ComponentPropsWithoutRef<typeof TooltipPrimitive.Root>) => {
  const [uncontrolled, setUncontrolled] = React.useState(!!defaultOpen)
  const isControlled = open !== undefined
  const value = isControlled ? !!open : uncontrolled

  const setOpen = React.useCallback(
    (next: boolean | ((prev: boolean) => boolean)) => {
      const resolved = typeof next === "function" ? next(value) : next
      if (!isControlled) setUncontrolled(resolved)
      onOpenChange?.(resolved)
    },
    [isControlled, onOpenChange, value],
  )

  // A tooltip pinned to a row that scrolls away should not linger.
  React.useEffect(() => {
    if (!value) return
    const close = () => setOpen(false)
    window.addEventListener("scroll", close, { passive: true, capture: true })
    return () => window.removeEventListener("scroll", close, { capture: true })
  }, [value, setOpen])

  return (
    <TooltipOpenContext.Provider value={{ open: value, setOpen }}>
      <TooltipPrimitive.Root open={value} onOpenChange={setOpen} {...props}>
        {children}
      </TooltipPrimitive.Root>
    </TooltipOpenContext.Provider>
  )
}

const TooltipTrigger = React.forwardRef<
  React.ElementRef<typeof TooltipPrimitive.Trigger>,
  React.ComponentPropsWithoutRef<typeof TooltipPrimitive.Trigger>
>(({ onPointerDown, onClick, ...props }, ref) => {
  const ctx = React.useContext(TooltipOpenContext)
  const touchRef = React.useRef(false)

  return (
    <TooltipPrimitive.Trigger
      ref={ref}
      onPointerDown={(event) => {
        touchRef.current = event.pointerType !== "mouse"
        onPointerDown?.(event)
        // Radix dismisses on pointerdown; on touch that would close the
        // tooltip a frame before the click below reopens it.
        if (touchRef.current && !event.defaultPrevented) event.preventDefault()
      }}
      onClick={(event) => {
        onClick?.(event)
        if (touchRef.current && ctx) ctx.setOpen((prev) => !prev)
      }}
      {...props}
    />
  )
})
TooltipTrigger.displayName = TooltipPrimitive.Trigger.displayName

const TooltipContent = React.forwardRef<
  React.ElementRef<typeof TooltipPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof TooltipPrimitive.Content>
>(({ className, sideOffset = 4, ...props }, ref) => (
  <TooltipPrimitive.Portal>
    <TooltipPrimitive.Content
      ref={ref}
      sideOffset={sideOffset}
      className={cn(
        "z-50 max-w-xs overflow-hidden rounded-md border bg-popover px-3 py-1.5 text-sm text-popover-foreground shadow-md animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",
        className
      )}
      {...props} />
  </TooltipPrimitive.Portal>
))
TooltipContent.displayName = TooltipPrimitive.Content.displayName

export { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider }
