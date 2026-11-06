"use client";
import React, { createContext, useCallback, useContext, useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { AnimatePresence } from "framer-motion";

// Zepto-style product story: on mobile, tapping a home-section product opens a
// full-screen swipeable sheet of that section's products instead of navigating.

const ProductStorySheet = dynamic(() => import("./ProductStorySheet"), {
  ssr: false,
});

type OpenStory = (products: any[], startId: any) => void;

const StoryOpenContext = createContext<OpenStory | null>(null);
const StoryListContext = createContext<any[] | null>(null);

export const ProductStoryProvider = ({ children }: { children: React.ReactNode }) => {
  const [story, setStory] = useState<{ products: any[]; index: number } | null>(
    null,
  );

  // Warm the sheet chunk so the first tap opens instantly.
  useEffect(() => {
    const id = setTimeout(() => {
      import("./ProductStorySheet");
    }, 1500);
    return () => clearTimeout(id);
  }, []);

  const open = useCallback<OpenStory>((products, startId) => {
    const index = Math.max(
      0,
      products.findIndex((p) => p?.id == startId),
    );
    setStory({ products, index });
  }, []);

  return (
    <StoryOpenContext.Provider value={open}>
      {children}
      <AnimatePresence>
        {story && (
          <ProductStorySheet
            key="product-story"
            products={story.products}
            startIndex={story.index}
            onClose={() => setStory(null)}
          />
        )}
      </AnimatePresence>
    </StoryOpenContext.Provider>
  );
};

/** Wrap a section's cards so a tap can open the story with its siblings. */
export const ProductStoryList = ({
  products,
  children,
}: {
  products: any[];
  children: React.ReactNode;
}) => (
  <StoryListContext.Provider value={products}>{children}</StoryListContext.Provider>
);

/**
 * Click handler for a card's product link. Returns undefined outside a story
 * list, so cards elsewhere keep plain navigation.
 */
export const useProductStoryClick = (productId: any) => {
  const open = useContext(StoryOpenContext);
  const list = useContext(StoryListContext);
  return useCallback(
    (e: React.MouseEvent) => {
      if (!open || !list?.length) return;
      if (!window.matchMedia("(max-width: 767px)").matches) return;
      if (e.metaKey || e.ctrlKey || e.shiftKey) return;
      if (e.defaultPrevented || (e.target as HTMLElement).closest("button")) return;
      e.preventDefault();
      // Tells NavigationProgress not to show its full-screen route loader.
      (e.nativeEvent as any).__noNavProgress = true;
      open(list, productId);
    },
    [open, list, productId],
  );
};
