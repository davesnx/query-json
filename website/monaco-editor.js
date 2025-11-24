import React from 'react';
import * as monaco from 'monaco-editor/esm/vs/editor/editor.api.js';
import 'monaco-editor/esm/vs/language/json/monaco.contribution.js';

import editorWorker from 'monaco-editor/esm/vs/editor/editor.worker.js?worker';
import jsonWorker from 'monaco-editor/esm/vs/language/json/json.worker.js?worker';

self.MonacoEnvironment = {
  getWorker(_, label) {
    if (label === 'json') {
      return new jsonWorker();
    }
    return new editorWorker();
  }
};

export default function Editor(props) {
  const containerRef = React.useRef(null);
  const editorRef = React.useRef(null);

  React.useEffect(() => {
    if (!containerRef.current) return;

    const editor = monaco.editor.create(containerRef.current, {
      value: props.value || '',
      language: props.language || 'json',
      theme: props.theme || 'vs-dark',
      ...props.options,
    });

    editorRef.current = editor;

    if (props.onChange) {
      editor.onDidChangeModelContent(() => {
        props.onChange(editor.getValue());
      });
    }

    return () => {
      editor.dispose();
    };
  }, []);

  React.useEffect(() => {
    if (editorRef.current && props.value !== undefined) {
      const currentValue = editorRef.current.getValue();
      if (currentValue !== props.value) {
        editorRef.current.setValue(props.value);
      }
    }
  }, [props.value]);

  React.useEffect(() => {
    if (editorRef.current && props.options) {
      editorRef.current.updateOptions(props.options);
    }
  }, [props.options]);

  return React.createElement('div', {
    ref: containerRef,
    style: { height: props.height || '100%', width: '100%', ...props.style },
    className: props.className,
  });
}

// Export loader API for compatibility
export const loader = {
  config: () => {},
  init: () => Promise.resolve(monaco),
};

