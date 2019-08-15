/*
fixed light
light transition to black between image changes
*/

#include "cinder/app/App.h"
#include "cinder/app/RendererGl.h"
#include "cinder/gl/gl.h"

// Settings
#include "VDSettings.h"
// Session
#include "VDSession.h"
// Log
#include "VDLog.h"
// Spout
#include "CiSpoutOut.h"
// warping
#include "Warp.h"
// UI
#define IMGUI_DISABLE_OBSOLETE_FUNCTIONS 1
#include "VDUI.h"
#define IM_ARRAYSIZE(_ARR)			((int)(sizeof(_ARR)/sizeof(*_ARR)))

using namespace ci;
using namespace ci::app;
using namespace std;
using namespace ph::warping;
using namespace videodromm;

class CrossApp : public App {

public:
	CrossApp();
	void mouseMove(MouseEvent event) override;
	void mouseDown(MouseEvent event) override;
	void mouseDrag(MouseEvent event) override;
	void mouseUp(MouseEvent event) override;
	void keyDown(KeyEvent event) override;
	void keyUp(KeyEvent event) override;
	void fileDrop(FileDropEvent event) override;
	void update() override;
	void draw() override;
	void cleanup() override;
	void toggleUIVisibility() { mVDSession->toggleUI(); };
	void toggleCursorVisibility(bool visible);
private:
	// Settings
	VDSettingsRef					mVDSettings;
	// Session
	VDSessionRef					mVDSession;
	// Log
	VDLogRef						mVDLog;
	// UI
	VDUIRef							mVDUI;
	// handle resizing for imgui
	void							resizeWindow();
	//! fbos
	void							renderToFbo();
	gl::FboRef						mFbo;
	//! shaders
	gl::GlslProgRef					mGlsl;
	bool							mUseShader;
	string							mError;
	// fbo
	bool							mIsShutDown;
	Anim<float>						mRenderWindowTimer;
	void							positionRenderWindow();
	bool							mFadeInDelay;
	SpoutOut 						mSpoutOut;
	// warping
	fs::path						mSettings;
	gl::TextureRef					mImage;
	WarpList						mWarps;
	Area							mSrcArea;
	int								mLastBar = 0;
	int								mSeqIndex = 1;
	float							mPreviousStart = 0.0f;
};


CrossApp::CrossApp()
	: mSpoutOut("Cross", app::getWindowSize())
{
	// Settings
	mVDSettings = VDSettings::create("Cross");
	// Session
	mVDSession = VDSession::create(mVDSettings);
	mVDSession->setSpeed(0, 0.0f);
	//mVDSettings->mCursorVisible = true;
	toggleCursorVisibility(mVDSettings->mCursorVisible);
	mVDSession->getWindowsResolution();
	mVDSession->toggleUI();
	mFadeInDelay = true;
	// UI
	mVDUI = VDUI::create(mVDSettings, mVDSession);
	// windows
	mIsShutDown = false;
	mRenderWindowTimer = 0.0f;
	//timeline().apply(&mRenderWindowTimer, 1.0f, 2.0f).finishFn([&] { positionRenderWindow(); });
	// warping
	mSettings = getAssetPath("") / "warps.xml";
	if (fs::exists(mSettings)) {
		// load warp settings from file if one exists
		mWarps = Warp::readSettings(loadFile(mSettings));
	}
	else {
		// otherwise create a warp from scratch
		mWarps.push_back(WarpPerspectiveBilinear::create());
	}
	// load test image .loadTopDown()
	try {
		mImage = gl::Texture::create(loadImage(loadAsset("c.jpg")), gl::Texture2d::Format().mipmap(true).minFilter(GL_LINEAR_MIPMAP_LINEAR));

		mSrcArea = mImage->getBounds();

		// adjust the content size of the warps
		Warp::setSize(mWarps, mImage->getSize());
	}
	catch (const std::exception &e) {
		console() << e.what() << std::endl;
	}
	// fbo
	gl::Fbo::Format format;
	//format.setSamples( 4 ); // uncomment this to enable 4x antialiasing
	mFbo = gl::Fbo::create(mVDSettings->mRenderWidth, mVDSettings->mRenderHeight, format.depthTexture());
	// shader
	mUseShader = true;
	mGlsl = gl::GlslProg::create(gl::GlslProg::Format().vertex(loadAsset("passthrough.vs")).fragment(loadAsset("crosslightz.glsl")));
	mVDSession->setBpm(160.0f);
	mVDSession->setSpeed(mSeqIndex, 0.0f);
	mVDSession->setFloatUniformValueByIndex(mVDSettings->IMOUSEX, 0.27710f);
	mVDSession->setFloatUniformValueByIndex(mVDSettings->IMOUSEY, 0.5648f);
	setWindowPos(10, 10);
}
void CrossApp::resizeWindow()
{
	mVDUI->resize();
	// tell the warps our window has been resized, so they properly scale up or down
	Warp::handleResize(mWarps);
}
void CrossApp::positionRenderWindow() {
	mVDSession->getWindowsResolution();
	mVDSettings->mRenderPosXY = ivec2(mVDSettings->mRenderX, mVDSettings->mRenderY);
	setWindowPos(mVDSettings->mRenderX, mVDSettings->mRenderY);
	setWindowSize(mVDSettings->mRenderWidth, mVDSettings->mRenderHeight);
}
void CrossApp::toggleCursorVisibility(bool visible)
{
	if (visible)
	{
		showCursor();
	}
	else
	{
		hideCursor();
	}
}
void CrossApp::fileDrop(FileDropEvent event)
{
	mVDSession->fileDrop(event);
}
void CrossApp::renderToFbo()
{

	// this will restore the old framebuffer binding when we leave this function
	// on non-OpenGL ES platforms, you can just call mFbo->unbindFramebuffer() at the end of the function
	// but this will restore the "screen" FBO on OpenGL ES, and does the right thing on both platforms
	gl::ScopedFramebuffer fbScp(mFbo);
	// clear out the FBO with black
	gl::clear(Color::black());

	// setup the viewport to match the dimensions of the FBO
	gl::ScopedViewport scpVp(ivec2(0), mFbo->getSize());

	// render
	// texture binding must be before ScopedGlslProg
	mImage->bind(0);
	gl::ScopedGlslProg prog(mGlsl);

	mGlsl->uniform("iTime", mVDSession->getFloatUniformValueByIndex(mVDSettings->ITIME) - mVDSettings->iStart);;
	mGlsl->uniform("iResolution", vec3(1280.0f, 720.0f, 1.0)); //vec3(mVDSettings->mRenderWidth, mVDSettings->mRenderHeight, 1.0));
	mGlsl->uniform("iChannel0", 0); // texture 0
	mGlsl->uniform("iBeat", (float)mVDSession->getIntUniformValueByIndex(mVDSettings->IBEAT));
	mGlsl->uniform("iBar", (float)mVDSession->getIntUniformValueByIndex(mVDSettings->IBAR));
	mGlsl->uniform("iTimeFactor", mVDSettings->iTimeFactor);
	mGlsl->uniform("iBpm", mVDSession->getFloatUniformValueByIndex(mVDSettings->IBPM));
	mGlsl->uniform("iBarBeat", (float)mVDSession->getIntUniformValueByIndex(mVDSettings->IBARBEAT));
	mGlsl->uniform("iExposure", mVDSession->getFloatUniformValueByIndex(mVDSettings->IEXPOSURE));
	mGlsl->uniform("iMouse", vec4(mVDSession->getFloatUniformValueByIndex(mVDSettings->IMOUSEX), mVDSession->getFloatUniformValueByIndex(mVDSettings->IMOUSEY), mVDSession->getFloatUniformValueByIndex(mVDSettings->IMOUSEZ), mVDSession->getFloatUniformValueByIndex(mVDSettings->IMOUSEZ)));
	//CI_LOG_V("iMouse x " + toString(mVDSession->getFloatUniformValueByIndex(mVDSettings->IMOUSEX)) +" y " + toString(mVDSession->getFloatUniformValueByIndex(mVDSettings->IMOUSEY)));
	gl::drawSolidRect(Rectf(0, 0, mVDSettings->mRenderWidth, mVDSettings->mRenderHeight));
}
void CrossApp::update()
{
	mVDSession->setFloatUniformValueByIndex(mVDSettings->IFPS, getAverageFps());
	mVDSession->update();

	// OK 1 bar mVDSession->setTimeFactor(3);
	// OK 2 bars mVDSession->setTimeFactor(2);
	// IBARBEAT = IBAR * 4 + IBEAT
	int current = mVDSession->getIntUniformValueByIndex(mVDSettings->IBARBEAT); 
	if (current == 22) {
		mVDSession->setPlayheadPosition(mSeqIndex, 7);
	}		
	if (mLastBar != mVDSession->getIntUniformValueByIndex(mVDSettings->IBAR)) {
		mLastBar = mVDSession->getIntUniformValueByIndex(mVDSettings->IBAR);
		if (mLastBar != 5 && mLastBar != 9) mVDSettings->iStart = mVDSession->getFloatUniformValueByIndex(mVDSettings->ITIME);
		if (mLastBar < 4) {
			mVDSession->setFloatUniformValueByIndex(mVDSettings->IEXPOSURE, 0.0f);
			//mVDSession->setTimeFactor(2); // 0.125f duration = 2 bar
			mVDSettings->iTimeFactor = 0.18; // 5 22
		}
		else if (mLastBar < 6) {
			mVDSession->setPlayheadPosition(mSeqIndex, 0);
			mVDSession->setFloatUniformValueByIndex(mVDSettings->IEXPOSURE, 1.93f);
		}
		else if (mLastBar < 7) {
			mVDSession->setPlayheadPosition(mSeqIndex, 1);

			//mVDSession->setTimeFactor(3); // 0.25f duration = 1 bar
			mVDSettings->iTimeFactor = 0.25;

		}
		else if (mLastBar < 8) {
			mVDSession->setPlayheadPosition(mSeqIndex, 2);
		}
		else if (mLastBar < 10) {
			mVDSession->setPlayheadPosition(mSeqIndex, 3);
			//mVDSession->setTimeFactor(2); // 0.125f duration = 2 bar
			mVDSettings->iTimeFactor = 0.18;
		}
		else if (mLastBar == 10) {
			mVDSession->setPlayheadPosition(mSeqIndex, 4);
			//mVDSession->setTimeFactor(3); // 0.25f duration = 1 bar
			mVDSettings->iTimeFactor = 0.25;
		}
		else
		{
			if (mVDSession->getPosition(mSeqIndex) > mVDSession->getMaxFrame(mSeqIndex) - 2) {
				mVDSession->setPlayheadPosition(mSeqIndex, 0);
			}
			else {
				mVDSession->incrementSequencePosition();
			}
		}
	}
	mImage = mVDSession->getInputTexture(mSeqIndex);
	mSrcArea = mImage->getBounds();
	if (mUseShader) {
		renderToFbo();
	}
	// adjust the content size of the warps
	Warp::setSize(mWarps, mImage->getSize());
}
void CrossApp::cleanup()
{
	if (!mIsShutDown)
	{
		mIsShutDown = true;
		CI_LOG_V("shutdown");
		// save warp settings
		Warp::writeSettings(mWarps, writeFile(mSettings));
		// save settings
		mVDSettings->save();
		mVDSession->save();
		quit();
	}
}
void CrossApp::mouseMove(MouseEvent event)
{
	if (!Warp::handleMouseMove(mWarps, event)) {
		if (!mVDSession->handleMouseMove(event)) {

		}
	}
}
void CrossApp::mouseDown(MouseEvent event)
{
	if (!Warp::handleMouseDown(mWarps, event)) {
		if (!mVDSession->handleMouseDown(event)) {
			mVDSession->setFloatUniformValueByIndex(mVDSettings->IMOUSEZ, 1.0f);
		}
	}
}
void CrossApp::mouseDrag(MouseEvent event)
{
	if (!Warp::handleMouseDrag(mWarps, event)) {
		if (!mVDSession->handleMouseDrag(event)) {
			mVDSession->setFloatUniformValueByIndex(mVDSettings->IMOUSEX, (float)event.getPos().x / (float)mVDSettings->mRenderWidth);
			mVDSession->setFloatUniformValueByIndex(mVDSettings->IMOUSEY, (float)event.getPos().y / (float)mVDSettings->mRenderHeight);

		}
	}
}
void CrossApp::mouseUp(MouseEvent event)
{
	if (!Warp::handleMouseUp(mWarps, event)) {
		if (!mVDSession->handleMouseUp(event)) {
			mVDSession->setFloatUniformValueByIndex(mVDSettings->IMOUSEZ, 0.0f);
			mVDSession->setFloatUniformValueByIndex(mVDSettings->IMOUSEX, 0.27710);
			mVDSession->setFloatUniformValueByIndex(mVDSettings->IMOUSEY, 0.5648);
		}
	}
}

void CrossApp::keyDown(KeyEvent event)
{
	if (!Warp::handleKeyDown(mWarps, event)) {
		if (!mVDSession->handleKeyDown(event)) {
			switch (event.getCode()) {
			case KeyEvent::KEY_ESCAPE:
				// quit the application
				quit();
				break;
			case KeyEvent::KEY_c:
				// mouse cursor and ui visibility
				mVDSettings->mCursorVisible = !mVDSettings->mCursorVisible;
				toggleCursorVisibility(mVDSettings->mCursorVisible);
				break;
			case KeyEvent::KEY_F10:
				mUseShader = !mUseShader;
				break;
			case KeyEvent::KEY_F11:
				// windows position
				positionRenderWindow();
				break;
			case KeyEvent::KEY_w:
				// toggle warp edit mode
				Warp::enableEditMode(!Warp::isEditModeEnabled());
				break;
			case KeyEvent::KEY_a:
				// toggle drawing a random region of the image
				if (mSrcArea.getWidth() != mImage->getWidth() || mSrcArea.getHeight() != mImage->getHeight())
					mSrcArea = mImage->getBounds();
				else {
					int x1 = Rand::randInt(0, mImage->getWidth() - 150);
					int y1 = Rand::randInt(0, mImage->getHeight() - 150);
					int x2 = Rand::randInt(x1 + 150, mImage->getWidth());
					int y2 = Rand::randInt(y1 + 150, mImage->getHeight());
					mSrcArea = Area(x1, y1, x2, y2);
				}
				break;
			}
		}
	}
}
void CrossApp::keyUp(KeyEvent event)
{
	if (!Warp::handleKeyUp(mWarps, event)) {
		if (!mVDSession->handleKeyUp(event)) {
		}
	}
}

void CrossApp::draw()
{
	gl::clear(Color::black());
	if (mFadeInDelay) {
		mVDSettings->iAlpha = 0.0f;
		if (getElapsedFrames() > mVDSession->getFadeInDelay()) {
			mFadeInDelay = false;
			timeline().apply(&mVDSettings->iAlpha, 0.0f, 1.0f, 1.5f, EaseInCubic());
		}
	}

	gl::setMatricesWindow(mVDSession->getIntUniformValueByIndex(mVDSettings->IOUTW), mVDSession->getIntUniformValueByIndex(mVDSettings->IOUTH), false);
	if (mImage) {
		for (auto &warp : mWarps) {
			if (mUseShader) {
				warp->draw(mFbo->getColorTexture(), mSrcArea);
			}
			else {
				warp->draw(mImage, mSrcArea);
			}
		}
	}

	// Spout Send
	//mSpoutOut.sendViewport();
	mSpoutOut.sendTexture(mFbo->getColorTexture());
	if (mVDSession->showUI()) {
		mVDUI->Run("UI", (int)getAverageFps());
		if (mVDUI->isReady()) {
		}
		getWindow()->setTitle(mVDSettings->sFps + " fps Cross");
	}
}

void prepareSettings(App::Settings *settings)
{
	settings->setWindowSize(1280, 720);
#ifdef _DEBUG
	//settings->setConsoleWindowEnabled();
#else
	//settings->setConsoleWindowEnabled();
#endif  // _DEBUG
}

CINDER_APP(CrossApp, RendererGl, prepareSettings)
