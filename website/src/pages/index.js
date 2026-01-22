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
            <div className="row" style={{alignItems: 'center', textAlign: 'left'}}>
              <div className="col col--6">
                <img 
                  src="img/logo.png" 
                  alt="FlowClip Icon" 
                  style={{width: '128px', height: '128px', marginBottom: '2rem'}} 
                />
                <h1 className="hero__title" style={{fontSize: '4rem', textAlign: 'left'}}>
                  FlowClip
                </h1>
                <p className="hero__subtitle" style={{textAlign: 'left', margin: '0 0 3rem 0'}}>
                  Clipboard manager for macOS which does one job<br />
                  - keep your copy history at hand. Period.<br /><br />
                  <strong>Lightweight. Open source. No fluff.</strong>
                </p>
                <div className="hero__buttons" style={{display: 'flex', gap: '1rem'}}>
                  <Link
                    className="button--bold"
                    to="https://github.com/gityeop/FlowClip/releases/latest">
                    Download now
                  </Link>
                  <p style={{marginTop: '1rem', fontSize: '0.9rem', color: 'var(--ifm-color-emphasis-600)'}}>
                    Requires macOS Sonoma 14 or higher
                  </p>
                </div>
              </div>
              <div className="col col--6">
                 <div style={{
                   background: '#fff', 
                   padding: '1rem',
                   borderRadius: '24px', 
                   boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
                   border: '1px solid #eee'
                 }}>
                   <img 
                     src="https://raw.githubusercontent.com/p0deje/Maccy/master/Screenshots/Main.png" 
                     alt="FlowClip Screenshot"
                     style={{borderRadius: '12px', width: '100%', display: 'block'}}
                   />
                 </div>
              </div>
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
