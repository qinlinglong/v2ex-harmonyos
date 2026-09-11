export interface V2exNode {
  id?: number;
  name: string;
  title: string;
  avatar_large?: string;
}

export interface V2exMember {
  id?: number;
  username: string;
  tagline?: string;
  avatar_large?: string;
  website?: string;
  bio?: string;
  created?: number;
  level?: number;
  reputation?: number;
}

export interface V2exTopic {
  id: number;
  title: string;
  content: string;
  url?: string;
  replies: number;
  last_modified: number;
  last_touched: number;
  /** Human-readable last-reply time from rendered topic lists. */
  lastTouchedLabel?: string;
  node?: V2exNode;
  member?: V2exMember;
  editable?: boolean;
  appendable?: boolean;
  favorited?: boolean;
  thanked?: boolean;
  ignored?: boolean;
  vote?: number;
  /** Current topic vote count returned by the H5 vote endpoint. */
  votes?: number;
  views?: number;
  likes?: number;
  thanks?: number;
  last_reply_by?: string;
  syntax?: string;
}

export interface V2exTopicStats {
  views?: number;
  likes?: number;
  thanks?: number;
}

export interface V2exVoteResult {
  success: boolean;
  changed: boolean;
  votes?: number;
  message?: string;
}

export interface V2exReply {
  id: number;
  /** 1-based floor number from the rendered H5 page, when available. */
  no?: number;
  /** Human-readable timestamp from the rendered H5 reply block. */
  createdLabel?: string;
  content: string;
  created: number;
  member?: V2exMember;
  topic_id?: number;
  topic_title?: string;
  thanks?: number;
  thanked?: boolean;
  /** Present only while the authenticated H5 page exposes edit/reply/:id. */
  editable?: boolean;
  op?: boolean;
  mod?: boolean;
}

export interface V2exNotification {
  id: number;
  once?: string;
  username: string;
  avatar?: string;
  topicId: number;
  topicTitle: string;
  content?: string;
  created?: string;
}

export interface V2exMemberRelations {
  followed: boolean;
  blocked: boolean;
}
