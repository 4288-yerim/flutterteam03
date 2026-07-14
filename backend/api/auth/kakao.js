import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import axios from 'axios';

if (!getApps().length) {
  initializeApp({
    credential: cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { accessToken, providerUserId, email, nickname } = req.body;

  if (!accessToken || !providerUserId) {
    return res.status(400).json({ error: 'accessToken과 providerUserId가 필요합니다.' });
  }

  try {
    const kakaoResponse = await axios.get('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    const verifiedKakaoId = kakaoResponse.data.id?.toString();

    if (verifiedKakaoId !== providerUserId) {
      return res.status(401).json({ error: '토큰 검증 실패: 유저 정보 불일치' });
    }

    const uid = `kakao_${verifiedKakaoId}`;
    let isNewUser = false;
    try {
      await getAuth().getUser(uid);
      isNewUser = false;
    } catch (err) {
      if (err.code === 'auth/user-not-found') {
        isNewUser = true;
      } else {
        throw err;
      }
    }

    const customToken = await getAuth().createCustomToken(uid, {
      provider: 'kakao',
      email: email || null,
      nickname: nickname || null,
    });

return res.status(200).json({ firebaseCustomToken: customToken, isNewUser });
  } catch (error) {
    console.error('카카오 토큰 검증/발급 실패:', error.response?.data || error.message);
    return res.status(401).json({ error: '카카오 토큰 검증 실패' });
  }
}