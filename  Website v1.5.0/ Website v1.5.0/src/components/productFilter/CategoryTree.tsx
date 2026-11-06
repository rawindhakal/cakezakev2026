import React, { useState, useEffect, useCallback } from "react";
import { ChevronRight, ChevronDown } from "lucide-react";

interface CategoryTreeNode {
  title: string;
  key: number | string;
  slug: string;
  image?: string;
  children: CategoryTreeNode[];
}

interface CategoryTreeInitialFilter {
  category_id?: string | number | null;
}

interface CategoryTreeProps {
  /** Category rows, raw API shape. */
  categories: any[];
  selectedCategories: (number | string)[];
  onCategoryChange: (categoryIds: (number | string)[], slugs: string[]) => void;
  /** Mount-time sync of the already-applied category. Falls back to onCategoryChange. */
  onInitialSelect?: (categoryIds: (number | string)[], slugs: string[]) => void;
  initialFilter?: CategoryTreeInitialFilter;
  /** Enable compact row layout. */
  compact?: boolean;
}

/** Category picker tree component with leaf selection model. */
const CategoryTree = ({
  categories,
  selectedCategories,
  onCategoryChange,
  onInitialSelect,
  initialFilter,
  compact = false,
}: CategoryTreeProps) => {
  const [treeData, setTreeData] = useState<CategoryTreeNode[]>([]);
  const [expandedKeys, setExpandedKeys] = useState<(number | string)[]>([]);

  // Transform categories into tree structure
  const transformCategoryData = useCallback((categories: any[]): CategoryTreeNode[] => {
    return categories?.map((category) => ({
      title: category?.translations?.name ?? category?.name,
      key: category.id,
      slug: category.slug,
      image: category?.image_url || "",
      children:
        category.cat_active_childs?.length > 0
          ? transformCategoryData(category.cat_active_childs)
          : [],
    }));
  }, []);

  // Initialize tree data when categories change
  useEffect(() => {
    if (categories?.length > 0) {
      const transformedData = transformCategoryData(categories);
      setTreeData(transformedData);
    }
  }, [categories, transformCategoryData]);

  // Auto-expand ancestor path of selected categories
  useEffect(() => {
    if (!treeData.length || !selectedCategories?.length) return;
    const selectedSet = new Set(selectedCategories.map((k) => String(k)));
    const ancestors: (number | string)[] = [];
    const hasSelectedDescendant = (node: CategoryTreeNode): boolean => {
      let found = selectedSet.has(String(node.key));
      (node.children || []).forEach((child) => {
        if (hasSelectedDescendant(child)) found = true;
      });
      if (found && node.children?.length) ancestors.push(node.key);
      return found;
    };
    treeData.forEach(hasSelectedDescendant);
    if (ancestors.length) {
      setExpandedKeys((prev) => [...new Set([...prev, ...ancestors])]);
    }
  }, [treeData, selectedCategories]);

  // Find entries in treeData for target keys
  const entriesForKeys = useCallback(
    (keys: (number | string)[]) => {
      const wanted = new Set(keys.map(String));
      const out: { key: number | string; slug: string }[] = [];
      const walk = (node: CategoryTreeNode) => {
        if (wanted.has(String(node.key)))
          out.push({ key: node.key, slug: node.slug });
        (node.children || []).forEach(walk);
      };
      treeData.forEach(walk);
      return out;
    },
    [treeData],
  );

  // Initialize selected categories from initial filter
  useEffect(() => {
    if (
      !treeData.length ||
      initialFilter?.category_id == null ||
      initialFilter?.category_id === ""
    ) {
      return;
    }
    // category_id may be a number (single leaf) or a comma-string (multi leaf).
    const catNum = String(initialFilter.category_id)
      .split(",")
      .filter((cat) => cat !== "")
      .map((cat) => parseInt(cat));
    const entries = entriesForKeys(catNum);
    // Return early if tree nodes haven't loaded for category selection
    if (catNum.length > 0 && entries.length === 0) return;
    const slugs = entries.map((e) => e.slug).filter(Boolean);
    (onInitialSelect ?? onCategoryChange)(catNum, slugs);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- onCategoryChange dependency excluded to prevent infinite rerenders
  }, [initialFilter, treeData, entriesForKeys]);

  const handleExpandCollapse = (nodeKey: number | string) => {
    setExpandedKeys((prev) =>
      prev.includes(nodeKey)
        ? prev.filter((key) => key !== nodeKey)
        : [...prev, nodeKey],
    );
  };

  // Retrieve all leaf keys under target node
  const getLeafKeys = (node: CategoryTreeNode): (number | string)[] => {
    if (!node.children?.length) return [node.key];
    return node.children.flatMap((child) => getLeafKeys(child));
  };

  const selectedSet = new Set(selectedCategories.map((k) => String(k)));

  // Calculate tri-state selection status for node
  const getNodeState = (node: CategoryTreeNode): "checked" | "indeterminate" | "unchecked" => {
    const leaves = getLeafKeys(node);
    const selectedCount = leaves.filter((k) =>
      selectedSet.has(String(k)),
    ).length;
    if (selectedCount === 0) return "unchecked";
    if (selectedCount === leaves.length) return "checked";
    return "indeterminate";
  };

  // Toggle selection state for category node
  const toggleNode = (node: CategoryTreeNode, ancestors: CategoryTreeNode[] = []) => {
    const leaves = getLeafKeys(node);
    const isLeaf = leaves.length === 1 && leaves[0] === node.key;

    let nextIds: (number | string)[];

    if (isLeaf) {
      const isSelected = selectedSet.has(String(node.key));
      // Find outermost fully checked ancestor
      const outermostCheckedAncestor = ancestors.find(
        (a) => getNodeState(a) === "checked",
      );

      if (outermostCheckedAncestor) {
        // Isolate selected leaf within checked subtree
        const subtreeLeaves = getLeafKeys(outermostCheckedAncestor);
        const subtreeSet = new Set(subtreeLeaves.map(String));
        const next = selectedCategories.filter(
          (k) => !subtreeSet.has(String(k)),
        );
        next.push(node.key);
        nextIds = next;
      } else if (isSelected) {
        // Remove selected leaf
        nextIds = selectedCategories.filter((k) => String(k) !== String(node.key));
      } else {
        // Add selected leaf
        nextIds = [...selectedCategories, node.key];
      }
    } else {
      // Toggle parent selection state for all child leaves
      const shouldSelect = getNodeState(node) !== "checked";
      const next = new Set(selectedCategories);
      leaves.forEach((k) => {
        if (shouldSelect) next.add(k);
        else next.delete(k);
      });
      nextIds = [...next];
    }

    const nextSlugs = entriesForKeys(nextIds)
      .map((e) => e.slug)
      .filter(Boolean);
    onCategoryChange(nextIds, nextSlugs);
  };

  // Recursive category tree node component
  const TreeNode = ({
    node,
    ancestors = [],
  }: {
    node: CategoryTreeNode;
    ancestors?: CategoryTreeNode[];
  }) => {
    const isExpanded = expandedKeys.includes(node.key);
    const hasChildren = node.children?.length > 0;
    const state = getNodeState(node);

    return (
      <div className={compact ? "ml-1" : "ml-1 md:ml-1.5 lg:ml-4"}>
        <div className={`flex items-center gap-2 ${compact ? "my-1" : "my-2.5"}`}>
          {/* Expand/Collapse Arrow */}
          <div className="w-4 h-4 flex-shrink-0 flex items-center justify-center">
            {hasChildren && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  handleExpandCollapse(node.key);
                }}
                className="focus:outline-none flex items-center justify-center"
              >
                {isExpanded ? (
                  <ChevronDown
                    className={`h-4 w-4 ${state !== "unchecked" ? "primaryColor" : "text-gray-500"}`}
                  />
                ) : (
                  <ChevronRight className="h-4 w-4 text-gray-500" />
                )}
              </button>
            )}
          </div>

          <div
            role="checkbox"
            tabIndex={0}
            aria-checked={
              state === "indeterminate" ? "mixed" : state === "checked"
            }
            aria-label={node.title}
            className="flex items-center gap-2 cursor-pointer flex-grow min-w-0"
            onClick={() => toggleNode(node, ancestors)}
            onKeyDown={(e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                toggleNode(node, ancestors);
              }
            }}
          >
            {node.image ? (
              // Same thumb treatment as the brand rows.
              <span
                className={`flex shrink-0 items-center justify-center overflow-hidden rounded-md border cardBorder bg-white ${
                  compact ? "h-7 w-7" : "h-8 w-8"
                }`}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={node.image}
                  alt={node.title}
                  className="h-full w-full object-contain p-0.5"
                  loading="lazy"
                />
              </span>
            ) : null}
            <span
              className={`text-ellipsis truncate ${compact ? "text-sm" : "text-[15px]"} ${
                state !== "unchecked"
                  ? "primaryColor font-medium"
                  : "text-gray-600 hover:text-black"
              }`}
            >
              {node.title}
            </span>
          </div>
        </div>
        {hasChildren && isExpanded && (
          <div>
            {node.children.map((child) => (
              <TreeNode
                key={child.key}
                node={child}
                ancestors={[...ancestors, node]}
              />
            ))}
          </div>
        )}
      </div>
    );
  };

  return (
    <div
      className={
        compact ? "overflow-y-auto" : "overflow-y-auto px-2 pb-4 md:px-2 lg:px-4"
      }
    >
      {treeData.map((node) => (
        <TreeNode key={node.key} node={node} />
      ))}
    </div>
  );
};

export default CategoryTree;
