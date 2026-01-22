import React from 'react';
import ComponentCreator from '@docusaurus/ComponentCreator';

export default [
  {
    path: '/FlowClip/',
    component: ComponentCreator('/FlowClip/', '498'),
    exact: true
  },
  {
    path: '*',
    component: ComponentCreator('*'),
  },
];
