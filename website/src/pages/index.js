import React from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`${siteConfig.title}`}
      description="FlowClip: Clipboard, built for flow.">
      <main>
        <div className="hero">
          <div className="container">
            <h1 className="hero__title">
              FlowClip: <br />
              Clipboard, <br />
              built for flow.
            </h1>
            <p className="hero__subtitle">
              The lightweight, keyboard-first clipboard manager for macOS <br />
              with powerful sequential pasting and batch operations.
            </p>
            <div className="hero__buttons">
              <Link
                className="button--bold"
                to="https://github.com/gityeop/FlowClip/releases/latest">
                Download Now
              </Link>
            </div>
          </div>
        </div>

        <section style={{padding: '5rem 0', backgroundColor: 'var(--ifm-color-emphasis-100)'}}>
          <div className="container">
            <div className="row" style={{alignItems: 'center'}}>
              <div className="col col--6">
                <h2 style={{fontSize: '3rem', marginBottom: '2rem'}}>Queue Clipboard.</h2>
                <p style={{fontSize: '1.25rem', color: 'var(--ifm-color-emphasis-700)', lineHeight: '1.6'}}>
                  Build a queue of items simply by copying multiple times. 
                  Paste them one by one or join them with custom separators. 
                  FlowClip keeps your momentum alive.
                </p>
              </div>
              <div className="col col--6">
                 {/* Placeholder for screenshot/visual */}
                 <div style={{
                   background: '#000', 
                   borderRadius: '24px', 
                   aspectRatio: '16/10', 
                   boxShadow: '0 20px 40px rgba(0,0,0,0.2)',
                   display: 'flex',
                   alignItems: 'center',
                   justifyContent: 'center',
                   color: '#fff',
                   fontWeight: '800'
                 }}>
                   PRODUCT VISUAL
                 </div>
              </div>
            </div>
          </div>
        </section>

        <section style={{padding: '5rem 0'}}>
          <div className="container">
            <div className="row">
               {[
                 {title: 'Keyboard First', desc: 'No mouse required. Total control at your fingertips.'},
                 {title: 'Native Performance', desc: 'Lightweight and fast. Designed specifically for macOS.'},
                 {title: 'Privacy Conscious', desc: 'Local-only storage. Your data stays on your machine.'},
               ].map((feature, idx) => (
                 <div key={idx} className="col col--4">
                   <h3 style={{fontSize: '2rem', marginBottom: '1rem'}}>{feature.title}</h3>
                   <p style={{fontSize: '1.1rem', color: 'var(--ifm-color-emphasis-700)'}}>{feature.desc}</p>
                 </div>
               ))}
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
