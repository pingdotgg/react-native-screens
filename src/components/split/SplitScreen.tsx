import React from 'react';
import { StyleSheet } from 'react-native';
import warnOnce from 'warn-once';
import SplitScreenNativeComponent from '../../fabric/split/SplitScreenNativeComponent';
import SplitColumnMarkerContext from './SplitColumnMarkerContext';
import type {
  SplitColumnProps,
  SplitInspectorProps,
} from './SplitScreen.types';

/**
 * Reads `disableStackIntegration` once, when the column is mounted, and tells
 * a `Stack.Host` rendered as its child whether to integrate with it.
 */
function useStackIntegration(
  disableStackIntegration: boolean,
  componentName: string,
) {
  const [isStackIntegrationDisabled] = React.useState(disableStackIntegration);

  React.useEffect(() => {
    warnOnce(
      disableStackIntegration !== isStackIntegrationDisabled,
      `[RNScreens] \`disableStackIntegration\` of ${componentName} cannot be changed after the column is mounted. The change is ignored.`,
    );
  }, [disableStackIntegration, isStackIntegrationDisabled, componentName]);

  return !isStackIntegrationDisabled;
}

function Column(props: SplitColumnProps) {
  const { children, disableStackIntegration = false, ...restProps } = props;

  // The integration with a stack is configured once, when the column is
  // mounted. `Stack.Host` and `Stack.Screen` read it from the context.
  const integratesStack = useStackIntegration(
    disableStackIntegration,
    'Split.Column',
  );

  return (
    <SplitScreenNativeComponent
      columnType="column"
      {...restProps}
      style={StyleSheet.absoluteFill}>
      <SplitColumnMarkerContext.Provider value={integratesStack}>
        {children}
      </SplitColumnMarkerContext.Provider>
    </SplitScreenNativeComponent>
  );
}

function Inspector(props: SplitInspectorProps) {
  const { children, disableStackIntegration = false, ...restProps } = props;

  const integratesStack = useStackIntegration(
    disableStackIntegration,
    'Split.Inspector',
  );

  return (
    <SplitScreenNativeComponent
      columnType="inspector"
      {...restProps}
      style={StyleSheet.absoluteFill}>
      <SplitColumnMarkerContext.Provider value={integratesStack}>
        {children}
      </SplitColumnMarkerContext.Provider>
    </SplitScreenNativeComponent>
  );
}

// TODO: refactor to drop `Screen` suffix as the API name is really long at the moment
const SplitScreen = {
  Column,
  Inspector,
};

export default SplitScreen;
