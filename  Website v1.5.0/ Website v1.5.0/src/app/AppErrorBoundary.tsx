 "use client";

import { Component, type ReactNode } from "react";

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
}

// Self-heals the dev Fast Refresh + Radix portal "removeChild" crash, which
// otherwise leaves a blank screen until hard reload.
class AppErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch() {
    // One-off commit glitch — re-render next tick.
    setTimeout(() => this.setState({ hasError: false }), 0);
  }

  render() {
    if (this.state.hasError) return null;
    return this.props.children;
  }
}

export default AppErrorBoundary;
