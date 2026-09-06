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
  node?: V2exNode;
  member?: V2exMember;
  editable?: boolean;
  appendable?: boolean;
  favorited?: boolean;
  thanked?: boolean;
  ignored?: boolean;
  vote?: number;
}

export interface V2exReply {
  id: number;
  content: string;
  created: number;
  member?: V2exMember;
  topic_id?: number;
  topic_title?: string;
  thanks?: number;
  thanked?: boolean;
}

export interface V2exNotification {
  id: number;
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
